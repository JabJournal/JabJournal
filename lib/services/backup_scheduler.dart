import 'dart:async';

import '../providers/backup_provider.dart';

/// Debounces automatic backups so that a burst of rapid changes (e.g. a bulk
/// import or quickly editing several fields) collapses into a single backup
/// file rather than one per keystroke.
///
/// Call [configure] once at startup with the [BackupProvider] instance, then
/// call [scheduleBackup] from any data-mutating provider after a successful
/// write. If auto-backup is disabled the call is a no-op.
class BackupScheduler {
  BackupScheduler._();
  static final instance = BackupScheduler._();

  static const _debounce = Duration(seconds: 5);

  BackupProvider? _provider;
  Timer? _timer;

  void configure(BackupProvider provider) {
    _provider = provider;
  }

  void scheduleBackup() {
    final provider = _provider;
    if (provider == null || !provider.autoBackupEnabled) return;
    _timer?.cancel();
    _timer = Timer(_debounce, () => provider.saveLocalBackup());
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
  }
}
