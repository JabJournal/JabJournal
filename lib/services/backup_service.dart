import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';

import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/dose_history.dart';
import '../models/peptide.dart';
import '../models/peptide_calculation.dart';
import '../models/schedule.dart';
import '../models/weight_entry.dart';
import 'database/database_helper.dart';
import 'saf_channel.dart';

// ─── Value types ──────────────────────────────────────────────────────────────

class BackupFileInfo {
  /// File-system path on desktop, or SAF document URI (`content://…`) on Android.
  final String path;
  final String? _displayName;
  final int sizeBytes;
  final DateTime modified;

  const BackupFileInfo({
    required this.path,
    String? displayName,
    required this.sizeBytes,
    required this.modified,
  }) : _displayName = displayName;

  /// Human-readable filename. Uses the explicit [displayName] when set
  /// (required for SAF URIs whose path component isn't a filename).
  String get filename => _displayName ?? path.split('/').last;

  String get formattedSize {
    if (sizeBytes < 1024) return '${sizeBytes}B';
    if (sizeBytes < 1024 * 1024) {
      return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

class BackupImportResult {
  final int peptides;
  final int doses;
  final int schedules;
  final int calculations;
  final int weights;

  const BackupImportResult({
    required this.peptides,
    required this.doses,
    required this.schedules,
    required this.calculations,
    this.weights = 0,
  });

  int get total => peptides + doses + schedules + calculations + weights;

  @override
  String toString() =>
      '$peptides peptides, $doses doses, $schedules schedules, $calculations calculations, $weights weights';
}

// ─── Exceptions ───────────────────────────────────────────────────────────────

class BackupPasswordRequiredException implements Exception {
  const BackupPasswordRequiredException();
}

class BackupWrongPasswordException implements Exception {
  const BackupWrongPasswordException();
}

class FilePickerNotReadyException implements Exception {
  final String detail;
  const FilePickerNotReadyException(this.detail);
}

// ─── Service ──────────────────────────────────────────────────────────────────

class BackupService {
  static const _backupDirName = 'jab_backups';
  static const _fileExtension = '.ptbackup';

  final _db = DatabaseHelper();

  // ── Encryption helpers ──────────────────────────────────────────────────────

  enc.Key _keyFromPassword(String password) {
    final bytes = sha256.convert(utf8.encode(password)).bytes;
    return enc.Key(Uint8List.fromList(bytes));
  }

  // ── Build backup JSON ───────────────────────────────────────────────────────

  Future<String> buildBackupJson({String? password}) async {
    final peptides = await _db.getAllPeptides();
    final doses = await _db.getAllDoses();
    final schedules = await _db.getAllSchedules();
    final calculations = await _db.getAllCalculations();
    final weights = await _db.getAllWeights();

    final dataMap = {
      'peptides': peptides.map((p) => p.toMap()).toList(),
      'doses': doses.map((d) => d.toMap()).toList(),
      'schedules': schedules.map((s) => s.toMap()).toList(),
      'calculations': calculations.map((c) => c.toMap()).toList(),
      'weights': weights.map((w) => w.toMap()).toList(),
    };

    final envelope = <String, dynamic>{
      'version': 1,
      'app': 'jab_journal',
      'exported_at': DateTime.now().millisecondsSinceEpoch,
    };

    if (password != null && password.isNotEmpty) {
      final dataJson = jsonEncode(dataMap);
      final key = _keyFromPassword(password);
      final iv = enc.IV.fromSecureRandom(16);
      final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
      final encrypted = encrypter.encrypt(dataJson, iv: iv);
      envelope['encrypted'] = true;
      envelope['iv'] = iv.base64;
      envelope['data'] = encrypted.base64;
    } else {
      envelope['encrypted'] = false;
      envelope['data'] = dataMap;
    }

    return const JsonEncoder.withIndent('  ').convert(envelope);
  }

  // ── Export via share sheet ──────────────────────────────────────────────────

  Future<void> exportAndShare({String? password}) async {
    final content = await buildBackupJson(password: password);
    final dir = await getTemporaryDirectory();
    final ts = DateTime.now().millisecondsSinceEpoch;
    final file = File('${dir.path}/jab_backup_$ts$_fileExtension');
    await file.parent.create(recursive: true);
    await file.writeAsString(content);
    await SharePlus.instance.share(ShareParams(
      files: [XFile(file.path)],
      subject: 'JabJournal Backup',
    ));
  }

  // ── Save backup ─────────────────────────────────────────────────────────────

  /// Saves a new backup. On Android, [dirPath] may be a SAF `content://` URI.
  /// Returns the file path or SAF document URI of the written file.
  Future<String> saveLocalBackup({String? password, String? dirPath}) async {
    final content = await buildBackupJson(password: password);
    final ts = DateTime.now().millisecondsSinceEpoch;
    final fileName = 'backup_$ts$_fileExtension';

    if (SafChannel.isSafUri(dirPath)) {
      return SafChannel.writeFile(
        treeUri: dirPath!,
        fileName: fileName,
        content: content,
      );
    }

    final dir = dirPath != null
        ? await _ensureDirectory(dirPath)
        : await _backupDirectory();
    final file = File('${dir.path}/$fileName');
    await file.writeAsString(content);
    return file.path;
  }

  // ── Read a backup file ──────────────────────────────────────────────────────

  Future<String> readBackupFile(String path) async {
    if (SafChannel.isSafUri(path)) {
      return SafChannel.readFile(path);
    }
    return File(path).readAsString();
  }

  // ── List & manage backups ───────────────────────────────────────────────────

  Future<List<BackupFileInfo>> listBackups({String? dirPath}) async {
    if (SafChannel.isSafUri(dirPath)) {
      final entries = await SafChannel.listFiles(
          treeUri: dirPath!, extension: _fileExtension);
      return entries
          .map((e) => BackupFileInfo(
                path: e.uri,
                displayName: e.name,
                sizeBytes: e.sizeBytes,
                modified: e.modified,
              ))
          .toList();
    }

    final dir = dirPath != null ? Directory(dirPath) : await _backupDirectory();
    if (!await dir.exists()) return [];
    final files = dir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith(_fileExtension))
        .toList()
      ..sort((a, b) =>
          b.statSync().modified.compareTo(a.statSync().modified));
    return files.map((f) {
      final stat = f.statSync();
      return BackupFileInfo(
        path: f.path,
        sizeBytes: stat.size,
        modified: stat.modified,
      );
    }).toList();
  }

  Future<void> pruneBackups(int keepCount, {String? dirPath}) async {
    if (keepCount <= 0) return;
    final backups = await listBackups(dirPath: dirPath);
    for (final b in backups.skip(keepCount)) {
      await deleteBackup(b.path);
    }
  }

  Future<void> deleteBackup(String path) async {
    if (SafChannel.isSafUri(path)) {
      await SafChannel.deleteFile(path);
      return;
    }
    final file = File(path);
    if (await file.exists()) await file.delete();
  }

  Future<Directory> _backupDirectory() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/$_backupDirName');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<Directory> _ensureDirectory(String path) async {
    final dir = Directory(path);
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<String> get defaultBackupDirectoryPath async {
    final dir = await _backupDirectory();
    return dir.path;
  }

  // ── Desktop Save As dialog ──────────────────────────────────────────────────

  Future<String?> pickAndSave({String? password}) async {
    final content = await buildBackupJson(password: password);
    final ts = DateTime.now().millisecondsSinceEpoch;
    final suggestedName = 'jab_backup_$ts$_fileExtension';

    final isDesktop =
        !kIsWeb && (Platform.isMacOS || Platform.isWindows || Platform.isLinux);

    if (isDesktop) {
      final path = await FilePicker.saveFile(
        dialogTitle: 'Save Backup',
        fileName: suggestedName,
        type: FileType.any,
      );
      if (path == null) return null;
      final resolvedPath =
          path.endsWith(_fileExtension) ? path : '$path$_fileExtension';
      final file = File(resolvedPath);
      await file.parent.create(recursive: true);
      await file.writeAsString(content);
      return file.path;
    }

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$suggestedName');
    await file.parent.create(recursive: true);
    await file.writeAsString(content);
    await SharePlus.instance.share(
      ShareParams(files: [XFile(file.path)], subject: 'JabJournal Backup'),
    );
    return file.path;
  }

  // ── Pick file for import ────────────────────────────────────────────────────

  Future<String?> pickAndReadFile() async {
    try {
      final result = await FilePicker.pickFiles(type: FileType.any);
      if (result == null || result.files.isEmpty) return null;
      final picked = result.files.single;

      // On Android, file_picker may expose a SAF URI via `identifier` rather
      // than a plain file path.
      final path = picked.path;
      if (path != null) return File(path).readAsString();

      // SAF-only path (Android content URI stored in `identifier`)
      final identifier = picked.identifier;
      if (identifier != null && SafChannel.isSafUri(identifier)) {
        return SafChannel.readFile(identifier);
      }

      return null;
    } on Error catch (e) {
      throw FilePickerNotReadyException(e.toString());
    }
  }

  bool isEncrypted(String jsonContent) {
    try {
      final envelope = jsonDecode(jsonContent) as Map<String, dynamic>;
      return envelope['encrypted'] == true;
    } catch (_) {
      return false;
    }
  }

  // ── Import ──────────────────────────────────────────────────────────────────

  Future<BackupImportResult> importData(
    String jsonContent, {
    String? password,
  }) async {
    final Map<String, dynamic> envelope;
    try {
      envelope = jsonDecode(jsonContent) as Map<String, dynamic>;
    } catch (_) {
      throw const FormatException('Invalid backup file format.');
    }

    const validApps = {'jab_journal', 'peptide_tracker'};
    if (!validApps.contains(envelope['app'])) {
      throw const FormatException('Not a valid JabJournal backup file.');
    }

    final encrypted = envelope['encrypted'] as bool? ?? false;
    Map<String, dynamic> data;

    if (encrypted) {
      if (password == null || password.isEmpty) {
        throw const BackupPasswordRequiredException();
      }
      final ivB64 = envelope['iv'] as String?;
      final cipherB64 = envelope['data'] as String?;
      if (ivB64 == null || cipherB64 == null) {
        throw const FormatException('Corrupt encrypted backup.');
      }
      try {
        final iv = enc.IV.fromBase64(ivB64);
        final key = _keyFromPassword(password);
        final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
        final decrypted = encrypter.decrypt64(cipherB64, iv: iv);
        data = jsonDecode(decrypted) as Map<String, dynamic>;
      } catch (_) {
        throw const BackupWrongPasswordException();
      }
    } else {
      data = envelope['data'] as Map<String, dynamic>;
    }

    int peptideCount = 0,
        doseCount = 0,
        scheduleCount = 0,
        calcCount = 0,
        weightCount = 0;

    for (final raw in (data['peptides'] as List? ?? [])) {
      await _db.insertPeptide(
          Peptide.fromMap(Map<String, dynamic>.from(raw as Map)));
      peptideCount++;
    }
    for (final raw in (data['doses'] as List? ?? [])) {
      await _db.insertDose(
          DoseHistory.fromMap(Map<String, dynamic>.from(raw as Map)));
      doseCount++;
    }
    for (final raw in (data['schedules'] as List? ?? [])) {
      await _db.insertSchedule(
          PeptideSchedule.fromMap(Map<String, dynamic>.from(raw as Map)));
      scheduleCount++;
    }
    for (final raw in (data['calculations'] as List? ?? [])) {
      await _db.insertCalculation(PeptideCalculation.fromMap(
          Map<String, dynamic>.from(raw as Map)));
      calcCount++;
    }
    for (final raw in (data['weights'] as List? ?? [])) {
      await _db.insertWeight(
          WeightEntry.fromMap(Map<String, dynamic>.from(raw as Map)));
      weightCount++;
    }

    return BackupImportResult(
      peptides: peptideCount,
      doses: doseCount,
      schedules: scheduleCount,
      calculations: calcCount,
      weights: weightCount,
    );
  }
}
