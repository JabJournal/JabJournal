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
      syncStatus: syncStatus ?? this.syncStatus,
      remoteId: remoteId ?? this.remoteId,
    );
  }

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
      'sync_status': syncStatus,
      'remote_id': remoteId,
    };
  }

  factory PeptideSchedule.fromMap(Map<String, dynamic> map) {
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
      syncStatus: map['sync_status'] ?? 'pending',
      remoteId: map['remote_id'],
    );
  }

  Map<String, dynamic> toJson() => toMap();

  factory PeptideSchedule.fromJson(Map<String, dynamic> json) =>
      PeptideSchedule.fromMap(json);
}
