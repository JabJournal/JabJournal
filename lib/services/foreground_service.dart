import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

/// Manages a persistent low-priority foreground service whose sole job is to
/// keep the app process alive so AlarmManager broadcasts (scheduled dose
/// reminders) reach a live process on battery-aggressive devices.
class PeptideForegroundService {
  static const _channelId = 'jab_journal_foreground';
  static const _channelName = 'Background Service';

  static void init() {
    if (!Platform.isAndroid) return;

    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: _channelId,
        channelName: _channelName,
        channelDescription:
            'Persistent background service that keeps JabJournal '
            'running so your scheduled dose reminders fire on time. '
            'Long-press this notification to silence it without affecting '
            'medication reminders.',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
        onlyAlertOnce: true,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.nothing(),
        autoRunOnBoot: true,
        autoRunOnMyPackageReplaced: true,
        allowWakeLock: true,
        allowWifiLock: false,
      ),
    );
  }

  static Future<bool> start() async {
    if (!Platform.isAndroid) return false;

    if (await FlutterForegroundTask.isRunningService) return true;

    final result = await FlutterForegroundTask.startService(
      notificationTitle: 'JabJournal is active',
      notificationText:
          'Keeping reminders on time. Long-press to silence this notification.',
      notificationIcon: null,
      notificationButtons: const [],
      callback: _startCallback,
    );

    return result is ServiceRequestSuccess;
  }

  static Future<bool> stop() async {
    if (!Platform.isAndroid) return true;
    if (!await FlutterForegroundTask.isRunningService) return true;
    final result = await FlutterForegroundTask.stopService();
    return result is ServiceRequestSuccess;
  }

  static Future<bool> isRunning() async {
    if (!Platform.isAndroid) return false;
    return FlutterForegroundTask.isRunningService;
  }
}

/// Top-level entry point invoked by the OS when the foreground service starts.
/// Runs in a separate Dart isolate — cannot share memory with the main isolate.
@pragma('vm:entry-point')
void _startCallback() {
  FlutterForegroundTask.setTaskHandler(_NoopTaskHandler());
}

class _NoopTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    debugPrint('[PeptideForegroundService] Started at $timestamp');
  }

  @override
  void onRepeatEvent(DateTime timestamp) {}

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    debugPrint('[PeptideForegroundService] Destroyed at $timestamp (timeout=$isTimeout)');
  }
}
