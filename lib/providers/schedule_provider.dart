import 'package:flutter/material.dart';
import '../models/peptide.dart';
import '../services/backup_scheduler.dart';
import '../models/schedule.dart';
import '../services/database/database_helper.dart';
import '../services/notification_router.dart';
import '../services/notification_service.dart';
import '../utils/peptide_colors.dart';

class ScheduleProvider with ChangeNotifier {
  final _db = DatabaseHelper();
  final _notifications = NotificationService();

  List<PeptideSchedule> _schedules = [];
  List<Peptide> _peptideList = [];
  bool _isLoading = false;
  String? _error;

  List<PeptideSchedule> get schedules => List.unmodifiable(_schedules);
  bool get isLoading => _isLoading;
  String? get error => _error;

  // ── Peptide list sync (called whenever PeptideProvider changes) ─────────────

  void updatePeptideList(List<Peptide> peptides) {
    _peptideList = peptides;
  }

  // ── Load ────────────────────────────────────────────────────────────────────

  Future<void> loadAllSchedules() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _schedules = await _db.getAllSchedules();
      // Cancel expired alarms and re-register every active alarm.
      // Re-registration is intentionally done on every launch: Android can
      // silently drop AlarmManager entries after a force-stop, OEM battery
      // optimisation kill, or backup restore, so this is the safety net.
      await rescheduleAllNotifications();
    } catch (e) {
      _error = 'Error loading schedules: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Cancels alarms for expired/disabled schedules and re-registers alarms for
  /// all active ones. Safe to call at any time — re-scheduling an existing
  /// alarm ID simply replaces it.
  Future<void> rescheduleAllNotifications() async {
    // Read peptide names straight from the DB so this works even before
    // PeptideProvider has populated _peptideList (e.g. during backup restore).
    final peptides = await _db.getAllPeptides();
    final nameById = {for (final p in peptides) p.id: p.name};

    for (final s in _schedules) {
      if (s.isExpired() || !s.enabled) {
        await _cancelNotificationsForSchedule(s);
      } else {
        await _scheduleNotifications(s, nameById[s.peptideId] ?? 'Unknown');
      }
    }

    // Re-register any pending rescheduled one-shots. We re-register the entry
    // with the latest future newDateTime per schedule — older ones are stale
    // (their notification slots are gone) and we leave them in the DB as
    // history so the calendar can still show "Rescheduled to …" for past days.
    for (final s in _schedules) {
      if (s.isExpired() || !s.enabled) continue;
      final pending = _latestPendingReschedule(s);
      if (pending == null) {
        // No active reschedule — make sure the slot is clear.
        await _notifications
            .cancelNotification(notificationIdForReschedule(s.id));
      } else {
        await _scheduleRescheduleOneShot(
          s,
          pending,
          nameById[s.peptideId] ?? 'Unknown',
        );
      }
    }
  }

  /// Returns the reschedule entry for [schedule] whose [RescheduledOccurrence.newDateTime]
  /// is still in the future and is the most recent. Returns null if none.
  RescheduledOccurrence? _latestPendingReschedule(PeptideSchedule schedule) {
    final now = DateTime.now();
    RescheduledOccurrence? latest;
    for (final r in schedule.rescheduledOccurrences) {
      if (!r.newDateTime.isAfter(now)) continue;
      if (latest == null || r.newDateTime.isAfter(latest.newDateTime)) {
        latest = r;
      }
    }
    return latest;
  }

  // ── Queries ─────────────────────────────────────────────────────────────────

  List<PeptideSchedule> schedulesForPeptide(String peptideId) =>
      _schedules.where((s) => s.peptideId == peptideId).toList();

  /// Returns {normalised-date → [schedules]} for a rolling window used by
  /// the calendar's eventLoader. Covers 4 weeks back + 8 weeks forward.
  ///
  /// Includes disabled schedules — the UI styles them differently rather than
  /// hiding them entirely, so the user understands "off" means paused, not
  /// deleted. One-shot schedules show only on their specific date. Weekly
  /// schedules with an end date stop showing past that date.
  ///
  /// Rescheduled occurrences appear on the new day in addition to the original
  /// day. If the user picked the "replace" option, the new day shows ONLY the
  /// rescheduled dose (the normal occurrence is suppressed). If they picked
  /// "keep both", both the normal and rescheduled entries appear on the new
  /// day. The original day always shows the schedule with a "Rescheduled to…"
  /// tag so the user can see where the dose was moved.
  Map<DateTime, List<PeptideSchedule>> buildEventMap() {
    final result = <DateTime, List<PeptideSchedule>>{};
    final today = DateTime.now();
    final start =
        DateTime(today.year, today.month, today.day).subtract(const Duration(days: 28));
    final end = start.add(const Duration(days: 28 + 56));

    for (var d = start; d.isBefore(end); d = d.add(const Duration(days: 1))) {
      final dayKey = DateTime(d.year, d.month, d.day);
      for (final s in _schedules) {
        if (s.frequency == ScheduleFrequency.once) {
          final sd = s.specificDate;
          if (sd == null) continue;
          final dateOnly = DateTime(sd.year, sd.month, sd.day);
          if (dateOnly != dayKey) continue;
        } else {
          // weekly
          if (s.daysOfWeek.isNotEmpty &&
              !s.daysOfWeek.contains(d.weekday)) {
            continue;
          }
          if (s.endDate != null) {
            final ed = DateTime(
                s.endDate!.year, s.endDate!.month, s.endDate!.day);
            if (dayKey.isAfter(ed)) continue;
          }
        }
        // Skip the normal occurrence if it has been replaced by a reschedule
        // that landed on this same day (and the user picked "replace").
        if (s.isOccurrenceReplaced(dayKey)) continue;
        (result[dayKey] ??= []).add(s);
      }
    }

    // Add rescheduled doses to their new day if the schedule isn't already
    // showing there as a normal occurrence (avoids double-listing). The card
    // uses [PeptideSchedule.rescheduleToDate] to render the "Rescheduled
    // from …" tag.
    for (final s in _schedules) {
      for (final r in s.rescheduledOccurrences) {
        final newDay = DateTime(
            r.newDateTime.year, r.newDateTime.month, r.newDateTime.day);
        if (newDay.isBefore(start) || !newDay.isBefore(end)) continue;
        final list = result[newDay] ??= [];
        if (!list.contains(s)) list.add(s);
      }
    }
    return result;
  }

  // ── CRUD ────────────────────────────────────────────────────────────────────

  Future<void> addSchedule(PeptideSchedule schedule,
      {required String peptideName}) async {
    try {
      await _db.insertSchedule(schedule);
      _schedules.add(schedule);
      notifyListeners();
      if (schedule.enabled) {
        await _scheduleNotifications(schedule, peptideName);
      }
      BackupScheduler.instance.scheduleBackup();
    } catch (e) {
      _error = 'Error adding schedule: $e';
      notifyListeners();
    }
  }

  Future<void> updateSchedule(PeptideSchedule schedule,
      {required String peptideName}) async {
    try {
      await _cancelNotificationsForSchedule(schedule);
      await _db.updateSchedule(schedule);
      final idx = _schedules.indexWhere((s) => s.id == schedule.id);
      if (idx != -1) _schedules[idx] = schedule;
      notifyListeners();
      if (schedule.enabled) {
        await _scheduleNotifications(schedule, peptideName);
      }
      BackupScheduler.instance.scheduleBackup();
    } catch (e) {
      _error = 'Error updating schedule: $e';
      notifyListeners();
    }
  }

  Future<void> deleteSchedule(String id) async {
    try {
      final schedule = _schedules.firstWhere((s) => s.id == id);
      await _cancelNotificationsForSchedule(schedule);
      await _db.deleteSchedule(id);
      _schedules.removeWhere((s) => s.id == id);
      notifyListeners();
      BackupScheduler.instance.scheduleBackup();
    } catch (e) {
      _error = 'Error deleting schedule: $e';
      notifyListeners();
    }
  }

  Future<void> toggleEnabled(String id) async {
    final idx = _schedules.indexWhere((s) => s.id == id);
    if (idx == -1) return;
    final current = _schedules[idx];
    final updated = current.copyWith(enabled: !current.enabled);
    await updateSchedule(updated,
        peptideName: peptideNameForSchedule(updated));
  }

  // ── Notification helpers ────────────────────────────────────────────────────

  int _notificationIdBase(String scheduleId) {
    final hex = scheduleId.replaceAll('-', '').substring(24);
    return (int.parse(hex, radix: 16) & 0x0FFFFFFF) * 10;
  }

  /// Day-of-week IDs (1=Mon … 7=Sun) used for weekly recurring notifications.
  int notificationIdForDay(String scheduleId, int dayOfWeek) =>
      _notificationIdBase(scheduleId) + dayOfWeek;

  /// Slot 0 (unused by weekly day-of-week IDs) is the one-shot reminder for
  /// [ScheduleFrequency.once] schedules.
  int _notificationIdForOnce(String scheduleId) =>
      _notificationIdBase(scheduleId);

  /// Slot 100 (well outside the 0..7 range used by once/weekly) holds the
  /// one-shot reminder for a manually rescheduled occurrence. Only one
  /// rescheduled reminder can be active per schedule at a time — re-rescheduling
  /// the same dose simply overwrites the previous rescheduled alarm.
  int notificationIdForReschedule(String scheduleId) =>
      _notificationIdBase(scheduleId) + 100;

  Future<void> _scheduleNotifications(
      PeptideSchedule s, String peptideName) async {
    if (s.isExpired()) return;

    final payload = NotificationRouter.buildSchedulePayload(
      scheduleId: s.id,
      peptideId: s.peptideId,
      peptideName: peptideName,
      dayOfWeek: 0, // not meaningful for the router; only peptide info is read
    );

    if (s.frequency == ScheduleFrequency.once) {
      final sd = s.specificDate;
      if (sd == null) return;
      // If this one-shot was already logged early, cancel and skip.
      if (s.isOccurrenceCompleted(sd)) {
        await _notifications.cancelNotification(_notificationIdForOnce(s.id));
        return;
      }
      final fireAt = DateTime(
        sd.year,
        sd.month,
        sd.day,
        s.timeOfDay ~/ 3600,
        (s.timeOfDay % 3600) ~/ 60,
      );
      if (fireAt.isBefore(DateTime.now())) return;
      await _notifications.scheduleOnceReminder(
        id: _notificationIdForOnce(s.id),
        title: 'Time for $peptideName',
        body: 'Your scheduled dose is due.',
        scheduledTime: fireAt,
        payload: payload,
      );
      return;
    }

    // Weekly (with or without end date — end date is enforced lazily on
    // app launch via loadAllSchedules cancelling expired ones).
    final today = DateTime.now();
    final todayKey = DateTime(today.year, today.month, today.day);
    for (final day in s.daysOfWeek) {
      // If today's occurrence for this day was already logged early, skip it
      // so the notification fires next week instead.
      final skipToday =
          s.isOccurrenceCompleted(todayKey) && todayKey.weekday == day;
      await _notifications.scheduleWeeklyNotification(
        id: notificationIdForDay(s.id, day),
        title: 'Time for $peptideName',
        body: 'Your scheduled dose is due.',
        dayOfWeek: day,
        secondsFromMidnight: s.timeOfDay,
        payload: payload,
        skipCurrentOccurrence: skipToday,
      );
    }
  }

  /// Records that the user logged a dose for [scheduleId] on [occurrenceDate]
  /// and suppresses the notification for that occurrence.
  Future<void> markOccurrenceComplete(
      String scheduleId, DateTime occurrenceDate) async {
    final idx = _schedules.indexWhere((s) => s.id == scheduleId);
    if (idx == -1) return;
    final schedule = _schedules[idx];

    if (schedule.isOccurrenceCompleted(occurrenceDate)) return;

    final dateStr =
        '${occurrenceDate.year}-${occurrenceDate.month.toString().padLeft(2, '0')}-${occurrenceDate.day.toString().padLeft(2, '0')}';
    // Also clear any reschedule that touched this date (either as the original
    // occurrence or as the rescheduled target) — logging the dose makes the
    // pending rescheduled reminder moot.
    final remainingReschedules = [...schedule.rescheduledOccurrences]
      ..removeWhere((r) =>
          '${r.originalDate.year}-${r.originalDate.month.toString().padLeft(2, '0')}-${r.originalDate.day.toString().padLeft(2, '0')}' ==
              dateStr ||
          '${r.newDateTime.year}-${r.newDateTime.month.toString().padLeft(2, '0')}-${r.newDateTime.day.toString().padLeft(2, '0')}' ==
              dateStr);
    final updated = schedule.copyWith(
      completedOccurrences: [...schedule.completedOccurrences, dateStr],
      rescheduledOccurrences: remainingReschedules,
    );

    try {
      await _db.updateSchedule(updated);
      _schedules[idx] = updated;
      notifyListeners();

      final peptideName = peptideNameForSchedule(updated);
      if (schedule.frequency == ScheduleFrequency.once) {
        await _notifications.cancelNotification(
            _notificationIdForOnce(schedule.id));
      } else {
        final day = occurrenceDate.weekday;
        if (schedule.daysOfWeek.contains(day)) {
          final payload = NotificationRouter.buildSchedulePayload(
            scheduleId: schedule.id,
            peptideId: schedule.peptideId,
            peptideName: peptideName,
            dayOfWeek: day,
          );
          await _notifications.cancelNotification(
              notificationIdForDay(schedule.id, day));
          await _notifications.scheduleWeeklyNotification(
            id: notificationIdForDay(schedule.id, day),
            title: 'Time for $peptideName',
            body: 'Your scheduled dose is due.',
            dayOfWeek: day,
            secondsFromMidnight: schedule.timeOfDay,
            payload: payload,
            skipCurrentOccurrence: true,
          );
        }
      }
      // Clear the rescheduled one-shot — the dose is logged, the reminder
      // should not fire.
      await _notifications
          .cancelNotification(notificationIdForReschedule(schedule.id));
      BackupScheduler.instance.scheduleBackup();
    } catch (e) {
      _error = 'Error marking occurrence complete: $e';
      notifyListeners();
    }
  }

  /// Brute-force cancel all notification IDs that could belong to this
  /// schedule — slot 0 for the one-shot, slots 1-7 for weekly day-of-week,
  /// slot 100 for any pending rescheduled one-shot.
  Future<void> _cancelNotificationsForSchedule(PeptideSchedule s) async {
    await _notifications.cancelNotification(_notificationIdForOnce(s.id));
    for (int day = 1; day <= 7; day++) {
      await _notifications
          .cancelNotification(notificationIdForDay(s.id, day));
    }
    await _notifications
        .cancelNotification(notificationIdForReschedule(s.id));
  }

  /// Re-schedules a single occurrence of [scheduleId] to fire at [newDateTime]
  /// as a one-shot reminder, leaving the original (and any future) occurrences
  /// untouched. Used by the "Re-schedule" action button on the notification
  /// and the "Re-schedule Dose" screen.
  ///
  /// The reschedule is persisted on the schedule (so it survives app restarts
  /// and shows up on the schedule page) and a one-shot alarm is registered in
  /// slot 100. If [replacesExistingOnNewDay] is true, the normal occurrence
  /// that would land on [newDateTime]'s date is suppressed (the rescheduled
  /// dose replaces it). If false, both events are shown.
  ///
  /// Re-rescheduling the same occurrence (same [originalDate]) overwrites the
  /// previous entry; rescheduling a different occurrence adds a new entry.
  Future<void> rescheduleOccurrence({
    required String scheduleId,
    required DateTime originalDate,
    required DateTime newDateTime,
    bool replacesExistingOnNewDay = false,
  }) async {
    final idx = _schedules.indexWhere((s) => s.id == scheduleId);
    if (idx == -1) return;
    final schedule = _schedules[idx];
    if (schedule.isExpired() || !schedule.enabled) return;
    if (!newDateTime.isAfter(DateTime.now())) return;

    final origDateOnly = DateTime(
        originalDate.year, originalDate.month, originalDate.day);
    final newEntry = RescheduledOccurrence(
      originalDate: origDateOnly,
      newDateTime: newDateTime,
      replacesExistingOnNewDay: replacesExistingOnNewDay,
    );

    // Replace any prior entry for the same original date so re-rescheduling
    // the same dose updates rather than stacks.
    final updatedList = [
      ...schedule.rescheduledOccurrences
          .where((r) => r.originalDate != origDateOnly),
      newEntry,
    ];

    final updated = schedule.copyWith(
      rescheduledOccurrences: updatedList,
      syncStatus: 'pending',
    );

    try {
      await _db.updateSchedule(updated);
      _schedules[idx] = updated;
      notifyListeners();

      final peptideName = peptideNameForSchedule(updated);
      await _scheduleRescheduleOneShot(updated, newEntry, peptideName);
      BackupScheduler.instance.scheduleBackup();
    } catch (e) {
      _error = 'Error rescheduling dose: $e';
      notifyListeners();
    }
  }

  /// Registers the one-shot alarm in the reschedule notification slot.
  Future<void> _scheduleRescheduleOneShot(
    PeptideSchedule schedule,
    RescheduledOccurrence entry,
    String peptideName,
  ) async {
    final payload = NotificationRouter.buildSchedulePayload(
      scheduleId: schedule.id,
      peptideId: schedule.peptideId,
      peptideName: peptideName,
      dayOfWeek: 0,
    );
    await _notifications.scheduleOnceReminder(
      id: notificationIdForReschedule(schedule.id),
      title: 'Time for $peptideName',
      body: 'Your scheduled dose is due.',
      scheduledTime: entry.newDateTime,
      payload: payload,
    );
  }

  // ── Color / name helpers (used by the calendar) ──────────────────────────────

  Color colorForSchedule(PeptideSchedule s) {
    final idx = _peptideList.indexWhere((p) => p.id == s.peptideId);
    return peptideColor(idx < 0 ? 0 : idx);
  }

  String peptideNameForSchedule(PeptideSchedule s) {
    try {
      return _peptideList.firstWhere((p) => p.id == s.peptideId).name;
    } catch (_) {
      return 'Unknown';
    }
  }
}
