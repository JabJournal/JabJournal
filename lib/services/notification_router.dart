import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../screens/doses/log_dose_screen.dart';
import '../screens/schedules/reschedule_dose_screen.dart';

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

  /// Action ID for the "Re-schedule" button on schedule reminder notifications.
  static const rescheduleDoseActionId = 'reschedule_dose';

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
  /// Action buttons route to different flows:
  ///   * [logDoseActionId]       → [LogDoseScreen] for the originating peptide
  ///   * [rescheduleDoseActionId] → [RescheduleDoseScreen] to pick a new time
  ///   * body tap / unknown      → [LogDoseScreen] (back-compat)
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
    final scheduleId = data['scheduleId'] as String?;
    final dayOfWeek = (data['dayOfWeek'] as int?) ?? 0;
    if (peptideId == null || peptideName == null) return;

    final isReschedule = response.actionId == rescheduleDoseActionId;

    if (navigatorKey.currentState == null) {
      // Widget tree not mounted yet (cold-start). Store for flushPending().
      if (isReschedule && scheduleId != null) {
        _pending = _PendingNav.reschedule(
          scheduleId: scheduleId,
          peptideId: peptideId,
          peptideName: peptideName,
          dayOfWeek: dayOfWeek,
        );
      } else {
        _pending = _PendingNav.logDose(
          peptideId: peptideId,
          peptideName: peptideName,
        );
      }
      return;
    }

    if (isReschedule && scheduleId != null) {
      _openReschedule(
        scheduleId: scheduleId,
        peptideId: peptideId,
        peptideName: peptideName,
        dayOfWeek: dayOfWeek,
      );
    } else {
      _openLogDose(peptideId: peptideId, peptideName: peptideName);
    }
  }

  // Holds navigation intent that arrived before the widget tree was mounted
  // (cold-start race condition on aggressive OEM task-killers like Samsung One UI).
  static _PendingNav? _pending;

  /// Call from HomeScreen.initState (addPostFrameCallback) to process any
  /// navigation that arrived before the widget tree was ready.
  static void flushPending() {
    final p = _pending;
    _pending = null;
    if (p == null) return;
    if (p.isReschedule) {
      _openReschedule(
        scheduleId: p.scheduleId!,
        peptideId: p.peptideId,
        peptideName: p.peptideName,
        dayOfWeek: p.dayOfWeek,
      );
    } else {
      _openLogDose(peptideId: p.peptideId, peptideName: p.peptideName);
    }
  }

  static bool _logDoseOpen = false;
  static bool _rescheduleOpen = false;

  static void _openLogDose({
    required String peptideId,
    required String peptideName,
  }) {
    if (_logDoseOpen) return;
    final navigator = navigatorKey.currentState;
    if (navigator == null) return;

    _logDoseOpen = true;
    navigator
        .push(
          MaterialPageRoute(
            builder: (_) => LogDoseScreen(
              peptideId: peptideId,
              peptideName: peptideName,
            ),
          ),
        )
        .whenComplete(() => _logDoseOpen = false);
  }

  static void _openReschedule({
    required String scheduleId,
    required String peptideId,
    required String peptideName,
    required int dayOfWeek,
  }) {
    if (_rescheduleOpen) return;
    final navigator = navigatorKey.currentState;
    if (navigator == null) return;

    final now = DateTime.now();
    final originalDate = DateTime(now.year, now.month, now.day);

    _rescheduleOpen = true;
    navigator
        .push(
          MaterialPageRoute(
            builder: (_) => RescheduleDoseScreen(
              scheduleId: scheduleId,
              peptideId: peptideId,
              peptideName: peptideName,
              dayOfWeek: dayOfWeek,
              originalDate: originalDate,
            ),
          ),
        )
        .whenComplete(() => _rescheduleOpen = false);
  }
}

class _PendingNav {
  final String peptideId;
  final String peptideName;
  final String? scheduleId;
  final int dayOfWeek;
  final bool isReschedule;

  const _PendingNav.logDose({
    required this.peptideId,
    required this.peptideName,
  })  : scheduleId = null,
        dayOfWeek = 0,
        isReschedule = false;

  const _PendingNav.reschedule({
    required this.scheduleId,
    required this.peptideId,
    required this.peptideName,
    required this.dayOfWeek,
  }) : isReschedule = true;
}
