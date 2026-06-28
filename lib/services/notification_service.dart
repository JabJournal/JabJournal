import 'dart:io' show Platform;

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import 'notification_router.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  late FlutterLocalNotificationsPlugin _localNotifications;
  bool _initialized = false;

  NotificationService._internal();

  factory NotificationService() => _instance;

  // ── Initialisation ──────────────────────────────────────────────────────────

  Future<void> initialize() async {
    if (_initialized) return;
    await _initTimezone();

    _localNotifications = FlutterLocalNotificationsPlugin();

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    final iOSSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
      notificationCategories: [
        DarwinNotificationCategory(
          'peptide_schedule_category',
          actions: [
            DarwinNotificationAction.plain(
              NotificationRouter.logDoseActionId,
              'Log Dose',
              options: {
                DarwinNotificationActionOption.foreground,
              },
            ),
            DarwinNotificationAction.plain(
              NotificationRouter.rescheduleDoseActionId,
              'Re-schedule',
              options: {
                DarwinNotificationActionOption.foreground,
              },
            ),
          ],
        ),
      ],
    );

    await _localNotifications.initialize(
      settings: InitializationSettings(
          android: androidSettings, iOS: iOSSettings),
      onDidReceiveNotificationResponse: NotificationRouter.handleResponse,
    );

    _initialized = true;
  }

  Future<void> _initTimezone() async {
    tz_data.initializeTimeZones();
    final tzInfo = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(tzInfo.identifier));
  }

  // ── Permissions ─────────────────────────────────────────────────────────────

  /// Asks the user for notification permission (Android 13+, iOS).
  /// Returns whether notifications are now enabled.
  Future<bool> requestNotificationPermission() async {
    if (!_initialized) await initialize();

    if (Platform.isIOS || Platform.isMacOS) {
      final ios = _localNotifications.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      final granted = await ios?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      return granted ?? false;
    }
    if (Platform.isAndroid) {
      final android = _localNotifications.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      final granted = await android?.requestNotificationsPermission();
      return granted ?? false;
    }
    return true;
  }

  /// Whether the OS currently allows us to post notifications.
  Future<bool> areNotificationsEnabled() async {
    if (!_initialized) await initialize();

    if (Platform.isAndroid) {
      final android = _localNotifications.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      return await android?.areNotificationsEnabled() ?? false;
    }
    if (Platform.isIOS) {
      final ios = _localNotifications.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      final settings = await ios?.checkPermissions();
      return settings?.isEnabled ?? false;
    }
    return true;
  }

  /// On Android 12+ the user must grant SCHEDULE_EXACT_ALARM in system settings
  /// for `exactAllowWhileIdle` schedules to fire on time.
  ///
  /// (USE_EXACT_ALARM is auto-granted but only available on API 33+ for medical /
  /// alarm clock apps — we declare both for max compatibility.)
  Future<bool> canScheduleExactAlarms() async {
    if (!_initialized) await initialize();
    if (!Platform.isAndroid) return true;

    final android = _localNotifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    return await android?.canScheduleExactNotifications() ?? false;
  }

  /// Opens the system "Alarms & reminders" / Special App Access page so the user
  /// can grant SCHEDULE_EXACT_ALARM. Only used on Android 12 (API 31) where
  /// USE_EXACT_ALARM isn't available.
  Future<void> requestExactAlarmPermission() async {
    if (!Platform.isAndroid) return;
    final android = _localNotifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.requestExactAlarmsPermission();
  }

  // ── Launch routing ──────────────────────────────────────────────────────────

  /// Checks whether the app was cold-started via a notification tap and, if so,
  /// forwards the response to [NotificationRouter.handleResponse].
  ///
  /// Call this from HomeScreen.initState (addPostFrameCallback) after the
  /// widget tree is live. It is a no-op if [NotificationRouter.flushPending]
  /// already has a pending navigation stored (meaning the plugin already called
  /// [onDidReceiveNotificationResponse] during [initialize]).
  Future<void> checkLaunchDetails() async {
    if (!_initialized) await initialize();
    final details = await _localNotifications.getNotificationAppLaunchDetails();
    if (details?.didNotificationLaunchApp != true) return;
    final response = details!.notificationResponse;
    if (response != null) {
      NotificationRouter.handleResponse(response);
    }
  }

  // ── One-shot notifications ──────────────────────────────────────────────────

  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    if (!_initialized) await initialize();
    await _localNotifications.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: _defaultDetails(),
      payload: payload,
    );
  }

  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
    String? payload,
  }) async {
    if (!_initialized) await initialize();
    await _localNotifications.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: tz.TZDateTime.from(scheduledTime, tz.local),
      notificationDetails: _defaultDetails(),
      androidScheduleMode: AndroidScheduleMode.alarmClock,
      payload: payload,
    );
  }

  /// Schedules a one-shot reminder on the schedule channel (with the
  /// "Log Dose" action button). Used for [ScheduleFrequency.once] schedules.
  Future<void> scheduleOnceReminder({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
    String? payload,
  }) async {
    if (!_initialized) await initialize();
    await _localNotifications.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: tz.TZDateTime.from(scheduledTime, tz.local),
      notificationDetails: _scheduleDetails(withLogDoseAction: true),
      androidScheduleMode: AndroidScheduleMode.alarmClock,
      payload: payload,
    );
  }

  // ── Recurring weekly notifications ──────────────────────────────────────────

  /// Schedules a weekly repeating notification on [dayOfWeek] (1=Mon…7=Sun)
  /// at the wall-clock time given by [secondsFromMidnight].
  ///
  /// The notification includes a "Log Dose" action button that deep-links to
  /// the dose-logging screen for the originating peptide.
  Future<void> scheduleWeeklyNotification({
    required int id,
    required String title,
    required String body,
    required int dayOfWeek,
    required int secondsFromMidnight,
    String? payload,
    bool skipCurrentOccurrence = false,
  }) async {
    if (!_initialized) await initialize();

    final hour = secondsFromMidnight ~/ 3600;
    final minute = (secondsFromMidnight % 3600) ~/ 60;

    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate = tz.TZDateTime(
        tz.local, now.year, now.month, now.day, hour, minute);

    while (scheduledDate.weekday != dayOfWeek) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    if (skipCurrentOccurrence || scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 7));
    }

    await _localNotifications.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: scheduledDate,
      notificationDetails: _scheduleDetails(withLogDoseAction: true),
      androidScheduleMode: AndroidScheduleMode.alarmClock,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      payload: payload,
    );
  }

  // ── Cancel ──────────────────────────────────────────────────────────────────

  Future<void> cancelNotification(int id) async =>
      _localNotifications.cancel(id: id);

  Future<void> cancelAllNotifications() async =>
      _localNotifications.cancelAll();

  // ── Details helpers ─────────────────────────────────────────────────────────

  static NotificationDetails _defaultDetails() => const NotificationDetails(
        android: AndroidNotificationDetails(
          'jab_journal_channel',
          'JabJournal Notifications',
          channelDescription: 'Notifications for peptide dose reminders',
          importance: Importance.max,
          priority: Priority.high,
          enableVibration: true,
          playSound: true,
        ),
        iOS: DarwinNotificationDetails(),
      );

  static NotificationDetails _scheduleDetails({
    bool withLogDoseAction = false,
  }) =>
      NotificationDetails(
        android: AndroidNotificationDetails(
          'peptide_schedule_channel',
          'Peptide Schedule Reminders',
          channelDescription: 'Weekly reminders for peptide dose schedules',
          importance: Importance.max,
          priority: Priority.high,
          enableVibration: true,
          playSound: true,
          category: AndroidNotificationCategory.reminder,
          actions: withLogDoseAction
              ? const [
                  AndroidNotificationAction(
                    NotificationRouter.logDoseActionId,
                    'Log Dose',
                    showsUserInterface: true,
                    cancelNotification: true,
                  ),
                  AndroidNotificationAction(
                    NotificationRouter.rescheduleDoseActionId,
                    'Re-schedule',
                    showsUserInterface: true,
                    cancelNotification: true,
                  ),
                ]
              : null,
        ),
        iOS: const DarwinNotificationDetails(
          categoryIdentifier: 'peptide_schedule_category',
        ),
      );
}
