import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../screens/doses/log_dose_screen.dart';

/// Owns the global navigator key and translates notification taps into
/// in-app navigation. Used by [NotificationService] when the user taps a
/// notification or one of its action buttons.
///
/// Lives outside the widget tree so the OS can route taps even when the
/// app was launched from a killed state.
class NotificationRouter {
  /// Pass to `MaterialApp.navigatorKey` so we can navigate from outside the
  /// widget tree.
  static final navigatorKey = GlobalKey<NavigatorState>();

  /// Action ID for the "Log Dose" button on schedule reminder notifications.
  static const logDoseActionId = 'log_dose';

  /// Builds the JSON payload encoded into a scheduled-reminder notification.
  /// We embed the peptide name + ID so the tap handler can navigate directly
  /// without having to reach into a Provider.
  static String buildSchedulePayload({
    required String scheduleId,
    required String peptideId,
    required String peptideName,
    required int dayOfWeek,
  }) {
    return jsonEncode({
      'type': 'schedule',
      'scheduleId': scheduleId,
      'peptideId': peptideId,
      'peptideName': peptideName,
      'dayOfWeek': dayOfWeek,
    });
  }

  /// Called by [FlutterLocalNotificationsPlugin] when the user taps the
  /// notification body or one of its action buttons.
  ///
  /// For the schedule reminder, we deep-link to [LogDoseScreen] for the
  /// originating peptide. Tapping the body and tapping the "Log Dose" action
  /// button do the same thing today, but we keep them separate in case we
  /// want different behaviors later (e.g. body opens the dashboard, action
  /// jumps straight to logging).
  static void handleResponse(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null || payload.isEmpty) return;

    Map<String, dynamic> data;
    try {
      data = jsonDecode(payload) as Map<String, dynamic>;
    } catch (_) {
      return;
    }

    final type = data['type'] as String?;
    if (type != 'schedule') return;

    final peptideId = data['peptideId'] as String?;
    final peptideName = data['peptideName'] as String?;
    if (peptideId == null || peptideName == null) return;

    _openLogDose(peptideId: peptideId, peptideName: peptideName);
  }

  static void _openLogDose({
    required String peptideId,
    required String peptideName,
  }) {
    final navigator = navigatorKey.currentState;
    if (navigator == null) return;

    navigator.push(
      MaterialPageRoute(
        builder: (_) => LogDoseScreen(
          peptideId: peptideId,
          peptideName: peptideName,
        ),
      ),
    );
  }
}
