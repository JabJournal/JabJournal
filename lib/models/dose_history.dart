import 'dart:convert';

/// Severity level of an injection site reaction.
enum IsrSeverity {
  none('None'),
  mild('Mild'),
  moderate('Moderate'),
  severe('Severe');

  final String label;
  const IsrSeverity(this.label);

  static IsrSeverity? fromString(String? value) {
    if (value == null || value.isEmpty) return null;
    for (final s in IsrSeverity.values) {
      if (s.name == value) return s;
    }
    return null;
  }
}

class DoseHistory {
  final String id;
  final String peptideId;
  final double amountMcg;
  final DateTime takenAt;
  final String? notes;

  /// Where the injection was administered (e.g. "Abdomen", "Left Thigh").
  final String? injectionSite;

  /// Side effects observed since the previous dose. Stored as a JSON list of strings.
  final List<String> sideEffects;

  /// Free-form description of any injection site reaction.
  final String? injectionSiteReaction;

  /// Severity of the injection site reaction.
  final IsrSeverity? isrSeverity;

  final String syncStatus;
  final String? remoteId;

  DoseHistory({
    required this.id,
    required this.peptideId,
    required this.amountMcg,
    required this.takenAt,
    this.notes,
    this.injectionSite,
    this.sideEffects = const [],
    this.injectionSiteReaction,
    this.isrSeverity,
    this.syncStatus = 'pending',
    this.remoteId,
  });

  DoseHistory copyWith({
    String? id,
    String? peptideId,
    double? amountMcg,
    DateTime? takenAt,
    String? notes,
    String? injectionSite,
    List<String>? sideEffects,
    String? injectionSiteReaction,
    IsrSeverity? isrSeverity,
    String? syncStatus,
    String? remoteId,
    bool clearInjectionSite = false,
    bool clearInjectionSiteReaction = false,
    bool clearIsrSeverity = false,
    bool clearNotes = false,
  }) {
    return DoseHistory(
      id: id ?? this.id,
      peptideId: peptideId ?? this.peptideId,
      amountMcg: amountMcg ?? this.amountMcg,
      takenAt: takenAt ?? this.takenAt,
      notes: clearNotes ? null : (notes ?? this.notes),
      injectionSite: clearInjectionSite ? null : (injectionSite ?? this.injectionSite),
      sideEffects: sideEffects ?? this.sideEffects,
      injectionSiteReaction: clearInjectionSiteReaction
          ? null
          : (injectionSiteReaction ?? this.injectionSiteReaction),
      isrSeverity: clearIsrSeverity ? null : (isrSeverity ?? this.isrSeverity),
      syncStatus: syncStatus ?? this.syncStatus,
      remoteId: remoteId ?? this.remoteId,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'peptide_id': peptideId,
      'amount_mcg': amountMcg,
      'taken_at': takenAt.millisecondsSinceEpoch,
      'notes': notes,
      'injection_site': injectionSite,
      'side_effects': sideEffects.isEmpty ? null : jsonEncode(sideEffects),
      'injection_site_reaction': injectionSiteReaction,
      'isr_severity': isrSeverity?.name,
      'sync_status': syncStatus,
      'remote_id': remoteId,
    };
  }

  factory DoseHistory.fromMap(Map<String, dynamic> map) {
    List<String> parsedEffects = const [];
    final raw = map['side_effects'];
    if (raw is String && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          parsedEffects = decoded.map((e) => e.toString()).toList();
        }
      } catch (_) {
        // If older data was stored as plain text, treat the whole string as one tag.
        parsedEffects = [raw];
      }
    }

    return DoseHistory(
      id: map['id'],
      peptideId: map['peptide_id'],
      amountMcg: (map['amount_mcg'] as num).toDouble(),
      takenAt: DateTime.fromMillisecondsSinceEpoch(map['taken_at']),
      notes: map['notes'],
      injectionSite: map['injection_site'],
      sideEffects: parsedEffects,
      injectionSiteReaction: map['injection_site_reaction'],
      isrSeverity: IsrSeverity.fromString(map['isr_severity'] as String?),
      syncStatus: map['sync_status'] ?? 'pending',
      remoteId: map['remote_id'],
    );
  }

  Map<String, dynamic> toJson() => toMap();

  factory DoseHistory.fromJson(Map<String, dynamic> json) =>
      DoseHistory.fromMap(json);
}
