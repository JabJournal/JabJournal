import 'package:flutter/services.dart';

// Thin Dart wrapper around the Android SAF method channel.
// [pickDirectory] and the write/list/read/delete methods only make sense on
// Android — the caller is responsible for gating on Platform.isAndroid.
class SafChannel {
  static const _ch = MethodChannel('app.jabjournal/saf');

  static bool isSafUri(String? path) =>
      path != null && path.startsWith('content://');

  /// Opens the Android `ACTION_OPEN_DOCUMENT_TREE` picker and returns the
  /// raw `content://` URI of the chosen directory, or null if cancelled.
  /// Calls `takePersistableUriPermission` so access survives app restarts.
  static Future<String?> pickDirectory() =>
      _ch.invokeMethod<String>('pickDirectory');

  /// Writes [content] as [fileName] inside the SAF tree at [treeUri].
  /// Returns the SAF document URI of the newly written file.
  static Future<String> writeFile({
    required String treeUri,
    required String fileName,
    required String content,
  }) async {
    final uri = await _ch.invokeMethod<String>('writeFile', {
      'treeUri': treeUri,
      'fileName': fileName,
      'content': content,
    });
    return uri!;
  }

  /// Lists files in [treeUri] that end with [extension], newest first.
  static Future<List<SafFileEntry>> listFiles({
    required String treeUri,
    required String extension,
  }) async {
    final raw = await _ch.invokeListMethod<Map>('listFiles', {
      'treeUri': treeUri,
      'extension': extension,
    });
    return raw?.map(SafFileEntry._fromMap).toList() ?? [];
  }

  /// Returns the UTF-8 text content of the SAF document at [fileUri].
  static Future<String> readFile(String fileUri) async {
    return await _ch.invokeMethod<String>('readFile', {'fileUri': fileUri}) ??
        '';
  }

  /// Deletes the SAF document at [fileUri]. Returns true on success.
  static Future<bool> deleteFile(String fileUri) async {
    return await _ch.invokeMethod<bool>('deleteFile', {'fileUri': fileUri}) ??
        false;
  }
}

class SafFileEntry {
  final String uri;
  final String name;
  final int sizeBytes;
  final DateTime modified;

  SafFileEntry({
    required this.uri,
    required this.name,
    required this.sizeBytes,
    required this.modified,
  });

  static SafFileEntry _fromMap(Map m) => SafFileEntry(
        uri: m['uri'] as String,
        name: m['name'] as String,
        sizeBytes: (m['size'] as num).toInt(),
        modified: DateTime.fromMillisecondsSinceEpoch(
            (m['lastModified'] as num).toInt()),
      );
}
