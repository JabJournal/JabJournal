import 'dart:convert';

/// How often a [PeptideSchedule] fires.
enum ScheduleFrequency {
  /// Fires once on a specific date and never again.
  once,

  /// Repeats weekly on the configured days of the week.
  weekly;

  String get storageKey {
    switch (this) {
      case ScheduleFrequency.once:
        return 'once';
      case ScheduleFrequency.weekly:
        return 'weekly';
    }
  }

  static ScheduleFrequency fromStorage(String? value) {
    switch (value) {
      case 'once':
        return ScheduleFrequency.once;
      case 'weekly':
      case 'custom': // legacy value used in v1/v2
      default:
        return ScheduleFrequency.weekly;
    }
  }
}

/// A single occurrence of a [PeptideSchedule] that was moved via the
/// "Re-schedule" action on a notification.
class RescheduledOccurrence {
  /// The original calendar date the dose was due (date-only, time = 00:00).
  final DateTime originalDate;

  /// The new fire time the user picked.
  final DateTime newDateTime;

  /// If true, any normal schedule occurrence that lands on [newDateTime]'s
  /// date is suppressed (the rescheduled dose replaces it). If false, the
  /// rescheduled dose is shown alongside any normal occurrence on the new day.
  final bool replacesExistingOnNewDay;

  const RescheduledOccurrence({
    required this.originalDate,
    required this.newDateTime,
    this.replacesExistingOnNewDay = false,
  });

  RescheduledOccurrence copyWith({
    DateTime? originalDate,
    DateTime? newDateTime,
    bool? replacesExistingOnNewDay,
  }) {
    return RescheduledOccurrence(
      originalDate: originalDate ?? this.originalDate,
      newDateTime: newDateTime ?? this.newDateTime,
      replacesExistingOnNewDay:
          replacesExistingOnNewDay ?? this.replacesExistingOnNewDay,
    );
  }

  Map<String, dynamic> toMap() => {
        'original_date': originalDate.millisecondsSinceEpoch,
        'new_date_time': newDateTime.millisecondsSinceEpoch,
        'replaces_existing_on_new_day':
            replacesExistingOnNewDay ? 1 : 0,
      };

  factory RescheduledOccurrence.fromMap(Map<String, dynamic> map) {
    return RescheduledOccurrence(
      originalDate:
          DateTime.fromMillisecondsSinceEpoch(map['original_date'] as int),
      newDateTime:
          DateTime.fromMillisecondsSinceEpoch(map['new_date_time'] as int),
      replacesExistingOnNewDay:
          (map['replaces_existing_on_new_day'] ?? 0) == 1,
    );
  }
}

class PeptideSchedule {
  final String id;
  final String peptideId;
  final ScheduleFrequency frequency;
  final List<int> daysOfWeek; // used when frequency == weekly
  final int timeOfDay; // seconds from midnight; used by both
  final bool enabled;

  /// For [ScheduleFrequency.once] — the specific calendar date the reminder
  /// should fire on. Combined with [timeOfDay] to produce the actual moment.
  final DateTime? specificDate;

  /// For [ScheduleFrequency.weekly] — optional cap. After this date the
  /// schedule no longer fires (we cancel its notifications on app launch).
  final DateTime? endDate;

  /// ISO date strings (YYYY-MM-DD) for occurrences the user already logged
  /// early so notifications for those days are suppressed.
  final List<String> completedOccurrences;

  /// Persisted record of doses the user moved via the "Re-schedule" action.
  /// Each entry moves one occurrence from [RescheduledOccurrence.originalDate]
  /// to [RescheduledOccurrence.newDateTime] without modifying the underlying
  /// schedule — future occurrences are unaffected.
  final List<RescheduledOccurrence> rescheduledOccurrences;

  final String syncStatus;
  final String? remoteId;

  PeptideSchedule({
    required this.id,
    required this.peptideId,
    this.frequency = ScheduleFrequency.weekly,
    this.daysOfWeek = const [],
    required this.timeOfDay,
    this.enabled = true,
    this.specificDate,
    this.endDate,
    this.completedOccurrences = const [],
    this.rescheduledOccurrences = const [],
    this.syncStatus = 'pending',
    this.remoteId,
  });

  PeptideSchedule copyWith({
    String? id,
    String? peptideId,
    ScheduleFrequency? frequency,
    List<int>? daysOfWeek,
    int? timeOfDay,
    bool? enabled,
    DateTime? specificDate,
    DateTime? endDate,
    List<String>? completedOccurrences,
    List<RescheduledOccurrence>? rescheduledOccurrences,
    String? syncStatus,
    String? remoteId,
    bool clearSpecificDate = false,
    bool clearEndDate = false,
  }) {
    return PeptideSchedule(
      id: id ?? this.id,
      peptideId: peptideId ?? this.peptideId,
      frequency: frequency ?? this.frequency,
      daysOfWeek: daysOfWeek ?? this.daysOfWeek,
      timeOfDay: timeOfDay ?? this.timeOfDay,
      enabled: enabled ?? this.enabled,
      specificDate: clearSpecificDate
          ? null
          : (specificDate ?? this.specificDate),
      endDate: clearEndDate ? null : (endDate ?? this.endDate),
      completedOccurrences: completedOccurrences ?? this.completedOccurrences,
      rescheduledOccurrences:
          rescheduledOccurrences ?? this.rescheduledOccurrences,
      syncStatus: syncStatus ?? this.syncStatus,
      remoteId: remoteId ?? this.remoteId,
    );
  }

  static String _dateKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  /// Returns true if the occurrence on [date] was already logged early.
  bool isOccurrenceCompleted(DateTime date) =>
      completedOccurrences.contains(_dateKey(date));

  /// True if this is a one-shot reminder whose date has passed, or a weekly
  /// reminder whose [endDate] has passed.
  bool isExpired({DateTime? now}) {
    final n = now ?? DateTime.now();
    final today = DateTime(n.year, n.month, n.day);
    if (frequency == ScheduleFrequency.once) {
      if (specificDate == null) return false;
      final d = DateTime(specificDate!.year, specificDate!.month,
          specificDate!.day);
      return d.isBefore(today);
    }
    if (endDate == null) return false;
    final e = DateTime(endDate!.year, endDate!.month, endDate!.day);
    return e.isBefore(today);
  }

  // ── Reschedule helpers ────────────────────────────────────────────────────

  /// Returns the reschedule entry whose original occurrence was on [date],
  /// or null if [date] has not been rescheduled.
  RescheduledOccurrence? rescheduleForOriginalDate(DateTime date) {
    final key = _dateKey(date);
    for (final r in rescheduledOccurrences) {
      if (_dateKey(r.originalDate) == key) return r;
    }
    return null;
  }

  /// Returns the reschedule entry that lands on [date], or null if none.
  RescheduledOccurrence? rescheduleToDate(DateTime date) {
    final key = _dateKey(date);
    for (final r in rescheduledOccurrences) {
      if (_dateKey(r.newDateTime) == key) return r;
    }
    return null;
  }

  /// True if the occurrence on [date] was rescheduled away to a different day.
  bool isOccurrenceRescheduled(DateTime date) =>
      rescheduleForOriginalDate(date) != null;

  /// True if the rescheduled dose landed on [date] (and the user picked the
  /// "replace" option, suppressing the normal occurrence for that day).
  bool isOccurrenceReplaced(DateTime date) {
    final r = rescheduleToDate(date);
    return r != null && r.replacesExistingOnNewDay;
  }

  /// Returns the new fire datetime for the reschedule whose original
  /// occurrence was on [date], or null.
  DateTime? rescheduleTarget(DateTime date) =>
      rescheduleForOriginalDate(date)?.newDateTime;

  /// Returns the original date for a reschedule that lands on [date],
  /// or null.
  DateTime? rescheduleOriginal(DateTime date) =>
      rescheduleToDate(date)?.originalDate;

  /// Removes all reschedule entries tied to [date] — either as the original
  /// occurrence or as the new fire date. Used when the user logs a dose.
  void clearReschedulesForDate(DateTime date) {
    rescheduledOccurrences
        .removeWhere((r) =>
            _dateKey(r.originalDate) == _dateKey(date) ||
            _dateKey(r.newDateTime) == _dateKey(date));
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'peptide_id': peptideId,
      'frequency': frequency.storageKey,
      'days_of_week': jsonEncode(daysOfWeek),
      'time_of_day': timeOfDay,
      'enabled': enabled ? 1 : 0,
      'specific_date': specificDate?.millisecondsSinceEpoch,
      'end_date': endDate?.millisecondsSinceEpoch,
      'completed_occurrences': jsonEncode(completedOccurrences),
      'rescheduled_occurrences':
          jsonEncode(rescheduledOccurrences.map((r) => r.toMap()).toList()),
      'sync_status': syncStatus,
      'remote_id': remoteId,
    };
  }

  factory PeptideSchedule.fromMap(Map<String, dynamic> map) {
    final rawReschedules = map['rescheduled_occurrences'];
    final reschedules = (rawReschedules is String && rawReschedules.isNotEmpty)
        ? (jsonDecode(rawReschedules) as List<dynamic>)
            .map((e) => RescheduledOccurrence.fromMap(e as Map<String, dynamic>))
            .toList()
        : <RescheduledOccurrence>[];
    return PeptideSchedule(
      id: map['id'],
      peptideId: map['peptide_id'],
      frequency: ScheduleFrequency.fromStorage(map['frequency'] as String?),
      daysOfWeek: List<int>.from(jsonDecode(map['days_of_week'] ?? '[]')),
      timeOfDay: map['time_of_day'],
      enabled: (map['enabled'] ?? 1) == 1,
      specificDate: map['specific_date'] == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(map['specific_date'] as int),
      endDate: map['end_date'] == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(map['end_date'] as int),
      completedOccurrences: List<String>.from(
          jsonDecode(map['completed_occurrences'] ?? '[]')),
      rescheduledOccurrences: reschedules,
      syncStatus: map['sync_status'] ?? 'pending',
      remoteId: map['remote_id'],
    );
  }

  Map<String, dynamic> toJson() => toMap();

  factory PeptideSchedule.fromJson(Map<String, dynamic> json) =>
      PeptideSchedule.fromMap(json);
}
