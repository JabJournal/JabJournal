/// A single weight measurement, optionally tied to a dose entry.
class WeightEntry {
  final String id;
  final double weightLbs;
  final DateTime recordedAt;
  final String? notes;

  /// Optional reference to the dose this weigh-in is associated with.
  final String? doseId;

  final String syncStatus;
  final String? remoteId;

  WeightEntry({
    required this.id,
    required this.weightLbs,
    required this.recordedAt,
    this.notes,
    this.doseId,
    this.syncStatus = 'pending',
    this.remoteId,
  });

  WeightEntry copyWith({
    String? id,
    double? weightLbs,
    DateTime? recordedAt,
    String? notes,
    String? doseId,
    String? syncStatus,
    String? remoteId,
    bool clearDoseId = false,
    bool clearNotes = false,
  }) {
    return WeightEntry(
      id: id ?? this.id,
      weightLbs: weightLbs ?? this.weightLbs,
      recordedAt: recordedAt ?? this.recordedAt,
      notes: clearNotes ? null : (notes ?? this.notes),
      doseId: clearDoseId ? null : (doseId ?? this.doseId),
      syncStatus: syncStatus ?? this.syncStatus,
      remoteId: remoteId ?? this.remoteId,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'weight_lbs': weightLbs,
      'recorded_at': recordedAt.millisecondsSinceEpoch,
      'notes': notes,
      'dose_id': doseId,
      'sync_status': syncStatus,
      'remote_id': remoteId,
    };
  }

  factory WeightEntry.fromMap(Map<String, dynamic> map) {
    return WeightEntry(
      id: map['id'],
      weightLbs: (map['weight_lbs'] as num).toDouble(),
      recordedAt: DateTime.fromMillisecondsSinceEpoch(map['recorded_at']),
      notes: map['notes'],
      doseId: map['dose_id'],
      syncStatus: map['sync_status'] ?? 'pending',
      remoteId: map['remote_id'],
    );
  }

  Map<String, dynamic> toJson() => toMap();

  factory WeightEntry.fromJson(Map<String, dynamic> json) =>
      WeightEntry.fromMap(json);
}
