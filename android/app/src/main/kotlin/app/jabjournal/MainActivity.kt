package app.jabjournal

import android.app.Activity
import android.content.ComponentName
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import androidx.documentfile.provider.DocumentFile
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channel = "app.jabjournal/saf"
    private val iconChannel = "app.jabjournal/icon"
    private val requestPickDirectory = 1001

    // Maps common variant identifiers to their activity-alias class names.
    private val iconAliases = mapOf(
        "forest"   to "app.jabjournal.MainActivityForest",
        "amethyst" to "app.jabjournal.MainActivityAmethyst",
        "slate"    to "app.jabjournal.MainActivitySlate",
    )
    private val mainActivity = "app.jabjournal.MainActivity"

    private var pendingPickResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // ── App icon switching channel ─────────────────────────────────────────
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, iconChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isSupported" -> result.success(true)

                    "getIcon" -> {
                        // Return the variant name whose alias is currently ENABLED,
                        // or null if MainActivity itself is the active entry (Ocean).
                        val active = iconAliases.entries.firstOrNull { (_, cls) ->
                            packageManager.getComponentEnabledSetting(
                                ComponentName(packageName, cls)
                            ) == PackageManager.COMPONENT_ENABLED_STATE_ENABLED
                        }
                        result.success(active?.key)
                    }

                    "setIcon" -> {
                        val variant = call.arguments as? String  // null → Ocean
                        try {
                            if (variant == null) {
                                // Activate Ocean: re-enable MainActivity, disable aliases.
                                packageManager.setComponentEnabledSetting(
                                    ComponentName(packageName, mainActivity),
                                    PackageManager.COMPONENT_ENABLED_STATE_DEFAULT,
                                    PackageManager.DONT_KILL_APP
                                )
                                iconAliases.values.forEach { cls ->
                                    packageManager.setComponentEnabledSetting(
                                        ComponentName(packageName, cls),
                                        PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
                                        PackageManager.DONT_KILL_APP
                                    )
                                }
                            } else {
                                val targetCls = iconAliases[variant]
                                    ?: return@setMethodCallHandler result.error(
                                        "UNKNOWN_VARIANT", "No alias for '$variant'", null)
                                // Disable MainActivity and all other aliases.
                                packageManager.setComponentEnabledSetting(
                                    ComponentName(packageName, mainActivity),
                                    PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
                                    PackageManager.DONT_KILL_APP
                                )
                                iconAliases.values.forEach { cls ->
                                    val state =
                                        if (cls == targetCls) PackageManager.COMPONENT_ENABLED_STATE_ENABLED
                                        else PackageManager.COMPONENT_ENABLED_STATE_DISABLED
                                    packageManager.setComponentEnabledSetting(
                                        ComponentName(packageName, cls),
                                        state,
                                        PackageManager.DONT_KILL_APP
                                    )
                                }
                            }
                            result.success(null)
                        } catch (e: Exception) {
                            result.error("ICON_ERROR", e.message, null)
                        }
                    }

                    else -> result.notImplemented()
                }
            }

        // ── Storage Access Framework channel ───────────────────────────────────
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    // ── Directory picker ────────────────────────────────────────
                    // Always returns the raw content:// URI so SAF write works
                    // reliably on Android 10+ scoped storage.
                    "pickDirectory" -> {
                        pendingPickResult = result
                        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).apply {
                            addFlags(
                                Intent.FLAG_GRANT_READ_URI_PERMISSION or
                                Intent.FLAG_GRANT_WRITE_URI_PERMISSION or
                                Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION
                            )
                        }
                        startActivityForResult(intent, requestPickDirectory)
                    }

                    // ── Write a file into a SAF tree ────────────────────────────
                    "writeFile" -> {
                        val treeUri = call.argument<String>("treeUri")!!
                        val fileName = call.argument<String>("fileName")!!
                        val content = call.argument<String>("content")!!
                        try {
                            val uri = Uri.parse(treeUri)
                            val dir = DocumentFile.fromTreeUri(this, uri)
                                ?: return@setMethodCallHandler result.error(
                                    "SAF_ERROR", "Cannot access directory", null)

                            // Replace any existing file with the same name.
                            dir.findFile(fileName)?.delete()
                            val file = dir.createFile("application/octet-stream", fileName)
                                ?: return@setMethodCallHandler result.error(
                                    "SAF_ERROR", "Cannot create file in directory", null)

                            contentResolver.openOutputStream(file.uri, "wt")?.use { stream ->
                                stream.write(content.toByteArray(Charsets.UTF_8))
                            } ?: return@setMethodCallHandler result.error(
                                "SAF_ERROR", "Cannot open output stream", null)

                            result.success(file.uri.toString())
                        } catch (e: Exception) {
                            result.error("SAF_ERROR", e.message, null)
                        }
                    }

                    // ── List .ptbackup files in a SAF tree ──────────────────────
                    "listFiles" -> {
                        val treeUri = call.argument<String>("treeUri")!!
                        val extension = call.argument<String>("extension")!!
                        try {
                            val uri = Uri.parse(treeUri)
                            val dir = DocumentFile.fromTreeUri(this, uri)
                                ?: return@setMethodCallHandler result.error(
                                    "SAF_ERROR", "Cannot access directory", null)

                            val files = dir.listFiles()
                                .filter { it.isFile && it.name?.endsWith(extension) == true }
                                .sortedByDescending { it.lastModified() }
                                .map { f ->
                                    mapOf(
                                        "uri" to f.uri.toString(),
                                        "name" to (f.name ?: ""),
                                        "size" to f.length(),
                                        "lastModified" to f.lastModified(),
                                    )
                                }
                            result.success(files)
                        } catch (e: Exception) {
                            result.error("SAF_ERROR", e.message, null)
                        }
                    }

                    // ── Read a SAF document ─────────────────────────────────────
                    "readFile" -> {
                        val fileUri = call.argument<String>("fileUri")!!
                        try {
                            val uri = Uri.parse(fileUri)
                            val stream = contentResolver.openInputStream(uri)
                                ?: return@setMethodCallHandler result.error(
                                    "SAF_ERROR", "Cannot open file", null)
                            result.success(stream.use { it.bufferedReader().readText() })
                        } catch (e: Exception) {
                            result.error("SAF_ERROR", e.message, null)
                        }
                    }

                    // ── Delete a SAF document ───────────────────────────────────
                    "deleteFile" -> {
                        val fileUri = call.argument<String>("fileUri")!!
                        try {
                            val uri = Uri.parse(fileUri)
                            val file = DocumentFile.fromSingleUri(this, uri)
                            result.success(file?.delete() == true)
                        } catch (e: Exception) {
                            result.error("SAF_ERROR", e.message, null)
                        }
                    }

                    else -> result.notImplemented()
                }
            }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == requestPickDirectory) {
            val res = pendingPickResult ?: return
            pendingPickResult = null

            if (resultCode == Activity.RESULT_OK) {
                val uri = data?.data
                if (uri != null) {
                    val flags = Intent.FLAG_GRANT_READ_URI_PERMISSION or
                                Intent.FLAG_GRANT_WRITE_URI_PERMISSION
                    contentResolver.takePersistableUriPermission(uri, flags)
                    res.success(uri.toString())
                } else {
                    res.success(null)
                }
            } else {
                res.success(null) // user cancelled
            }
        }
    }
}
