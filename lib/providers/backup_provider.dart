import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/backup_service.dart';

class BackupProvider with ChangeNotifier {
  final service = BackupService();

  // Settings
  bool _autoBackupEnabled = false;
  int _maxBackups = 5;
  bool _encryptionEnabled = false;
  String _backupPassword = '';
  String? _backupDirectory;
  String? _backupDirectoryDisplayName;

  // State
  DateTime? _lastBackupAt;
  bool _isBusy = false;
  String? _error;
  List<BackupFileInfo> _backups = [];

  bool get autoBackupEnabled => _autoBackupEnabled;
  int get maxBackups => _maxBackups;
  bool get encryptionEnabled => _encryptionEnabled;
  String get backupPassword => _backupPassword;
  String? get backupDirectory => _backupDirectory;
  String? get backupDirectoryDisplayName => _backupDirectoryDisplayName;
  DateTime? get lastBackupAt => _lastBackupAt;
  bool get isBusy => _isBusy;
  String? get error => _error;
  List<BackupFileInfo> get backups => List.unmodifiable(_backups);

  // ── Persistence ─────────────────────────────────────────────────────────────

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _autoBackupEnabled = prefs.getBool('backup_auto') ?? false;
    _maxBackups = prefs.getInt('backup_max') ?? 5;
    _encryptionEnabled = prefs.getBool('backup_encryption') ?? false;
    _backupPassword = prefs.getString('backup_password') ?? '';
    _backupDirectory = prefs.getString('backup_auto_dir');
    _backupDirectoryDisplayName = prefs.getString('backup_dir_name');
    final lastTs = prefs.getInt('backup_last_at');
    _lastBackupAt =
        lastTs != null ? DateTime.fromMillisecondsSinceEpoch(lastTs) : null;

    // Clean up keys left over from the old time-based scheduler.
    await prefs.remove('backup_frequency');
    await prefs.remove('backup_hour');
    await prefs.remove('backup_hour_utc');

    notifyListeners();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('backup_auto', _autoBackupEnabled);
    await prefs.setInt('backup_max', _maxBackups);
    await prefs.setBool('backup_encryption', _encryptionEnabled);
    await prefs.setString('backup_password', _backupPassword);
    if (_backupDirectory != null) {
      await prefs.setString('backup_auto_dir', _backupDirectory!);
    } else {
      await prefs.remove('backup_auto_dir');
    }
    if (_backupDirectoryDisplayName != null) {
      await prefs.setString('backup_dir_name', _backupDirectoryDisplayName!);
    } else {
      await prefs.remove('backup_dir_name');
    }
    if (_lastBackupAt != null) {
      await prefs.setInt(
          'backup_last_at', _lastBackupAt!.millisecondsSinceEpoch);
    }
  }

  // ── Settings setters ─────────────────────────────────────────────────────────

  Future<void> setAutoBackupEnabled(bool v) async {
    _autoBackupEnabled = v;
    await _persist();
    notifyListeners();
  }

  Future<void> setMaxBackups(int n) async {
    _maxBackups = n.clamp(1, 50);
    await _persist();
    notifyListeners();
  }

  Future<void> setEncryptionEnabled(bool v) async {
    _encryptionEnabled = v;
    if (!v) _backupPassword = '';
    await _persist();
    notifyListeners();
  }

  Future<void> setBackupPassword(String p) async {
    _backupPassword = p;
    await _persist();
    notifyListeners();
  }

  Future<void> setBackupDirectory(String? path, {String? displayName}) async {
    _backupDirectory = path;
    _backupDirectoryDisplayName = path != null ? displayName : null;
    await _persist();
    await loadBackups();
    notifyListeners();
  }

  // ── Backup actions ───────────────────────────────────────────────────────────

  Future<void> exportAndShare() async {
    _setBusy(true);
    try {
      final password = _encryptionEnabled ? _backupPassword : null;
      await service.exportAndShare(password: password);
    } catch (e) {
      _error = 'Export failed: $e';
      notifyListeners();
    } finally {
      _setBusy(false);
    }
  }

  Future<bool> saveLocalBackup() async {
    _setBusy(true);
    try {
      final password = _encryptionEnabled ? _backupPassword : null;
      await service.saveLocalBackup(
          password: password, dirPath: _backupDirectory);
      await service.pruneBackups(_maxBackups, dirPath: _backupDirectory);
      _lastBackupAt = DateTime.now();
      await _persist();
      await loadBackups();
      return true;
    } catch (e) {
      _error = 'Backup failed: $e';
      notifyListeners();
      return false;
    } finally {
      _setBusy(false);
    }
  }

  Future<void> loadBackups() async {
    _backups = await service.listBackups(dirPath: _backupDirectory);
    notifyListeners();
  }

  Future<void> deleteBackup(String path) async {
    await service.deleteBackup(path);
    await loadBackups();
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────

  void _setBusy(bool v) {
    _isBusy = v;
    if (v) _error = null;
    notifyListeners();
  }
}
