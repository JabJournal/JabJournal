import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

import '../services/notification_service.dart';

/// Tracks the OS-level prerequisites for scheduled notifications to actually
/// fire on time:
///   1. Notifications enabled (Android 13+ POST_NOTIFICATIONS)
///   2. Exact alarms allowed (Android 12+ SCHEDULE_EXACT_ALARM / USE_EXACT_ALARM)
///   3. Battery optimization disabled for the app (Doze / App Standby)
///
/// Exposes simple booleans the UI can react to, plus action methods that
/// trigger the appropriate OS dialogs.
class NotificationStatusProvider with ChangeNotifier {
  final _service = NotificationService();

  bool _notificationsEnabled = false;
  bool _exactAlarmsAllowed = false;
  bool _batteryOptimizationDisabled = false;
  bool _checked = false;

  bool get notificationsEnabled => _notificationsEnabled;
  bool get exactAlarmsAllowed => _exactAlarmsAllowed;
  bool get batteryOptimizationDisabled => _batteryOptimizationDisabled;
  bool get hasChecked => _checked;

  /// True if any prerequisite is missing — UI shows a warning banner when so.
  bool get hasIssues =>
      !_notificationsEnabled ||
      !_exactAlarmsAllowed ||
      (Platform.isAndroid && !_batteryOptimizationDisabled);

  /// Re-reads all OS state. Cheap to call — call this on screen entry / resume.
  Future<void> refresh() async {
    _notificationsEnabled = await _service.areNotificationsEnabled();
    _exactAlarmsAllowed = await _service.canScheduleExactAlarms();
    if (Platform.isAndroid) {
      final status = await Permission.ignoreBatteryOptimizations.status;
      _batteryOptimizationDisabled = status.isGranted;
    } else {
      _batteryOptimizationDisabled = true;
    }
    _checked = true;
    notifyListeners();
  }

  // ── Actions ─────────────────────────────────────────────────────────────────

  Future<bool> requestNotificationPermission() async {
    final granted = await _service.requestNotificationPermission();
    _notificationsEnabled = granted;
    notifyListeners();
    return granted;
  }

  Future<void> requestExactAlarmPermission() async {
    await _service.requestExactAlarmPermission();
    // The user has to leave the app and come back — refresh on resume picks
    // it up. Refresh now anyway in case it was a no-op.
    _exactAlarmsAllowed = await _service.canScheduleExactAlarms();
    notifyListeners();
  }

  /// Shows the system "Allow this app to ignore battery optimization?" dialog.
  /// On modern Android the dialog is a one-tap allow, no settings detour.
  Future<bool> requestDisableBatteryOptimization() async {
    if (!Platform.isAndroid) return true;
    final status = await Permission.ignoreBatteryOptimizations.request();
    _batteryOptimizationDisabled = status.isGranted;
    notifyListeners();
    return status.isGranted;
  }

  /// Fallback that opens the OS battery optimization screen for this app —
  /// useful if the dialog above was previously dismissed permanently.
  Future<void> openBatterySettings() async {
    if (!Platform.isAndroid) return;
    await openAppSettings();
  }

  /// Opens the app's notification settings (Android) / app settings (iOS) so
  /// the user can re-enable notifications they previously denied.
  Future<void> openNotificationSettings() async {
    await openAppSettings();
  }
}
