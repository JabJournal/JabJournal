class PeptideCalculation {
  final String id;
  final String peptideName;
  final String syringeType;
  final int syringeUnits;
  final double vialWaterMl;
  final double vialPeptideMl;
  final double desiredDoseMcg;
  final double resultAmount;
  final DateTime calculatedAt;
  final String syncStatus;
  final String? remoteId;

  PeptideCalculation({
    required this.id,
    required this.peptideName,
    required this.syringeType,
    required this.syringeUnits,
    required this.vialWaterMl,
    required this.vialPeptideMl,
    required this.desiredDoseMcg,
    required this.resultAmount,
    required this.calculatedAt,
    this.syncStatus = 'pending',
    this.remoteId,
  });

  PeptideCalculation copyWith({
    String? id,
    String? peptideName,
    String? syringeType,
    int? syringeUnits,
    double? vialWaterMl,
    double? vialPeptideMl,
    double? desiredDoseMcg,
    double? resultAmount,
    DateTime? calculatedAt,
    String? syncStatus,
    String? remoteId,
  }) {
    return PeptideCalculation(
      id: id ?? this.id,
      peptideName: peptideName ?? this.peptideName,
      syringeType: syringeType ?? this.syringeType,
      syringeUnits: syringeUnits ?? this.syringeUnits,
      vialWaterMl: vialWaterMl ?? this.vialWaterMl,
      vialPeptideMl: vialPeptideMl ?? this.vialPeptideMl,
      desiredDoseMcg: desiredDoseMcg ?? this.desiredDoseMcg,
      resultAmount: resultAmount ?? this.resultAmount,
      calculatedAt: calculatedAt ?? this.calculatedAt,
      syncStatus: syncStatus ?? this.syncStatus,
      remoteId: remoteId ?? this.remoteId,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'peptide_name': peptideName,
      'syringe_type': syringeType,
      'syringe_units': syringeUnits,
      'vial_water_ml': vialWaterMl,
      'vial_peptide_ml': vialPeptideMl,
      'desired_dose_mcg': desiredDoseMcg,
      'result_amount': resultAmount,
      'calculated_at': calculatedAt.millisecondsSinceEpoch,
      'sync_status': syncStatus,
      'remote_id': remoteId,
    };
  }

  factory PeptideCalculation.fromMap(Map<String, dynamic> map) {
    return PeptideCalculation(
      id: map['id'],
      peptideName: map['peptide_name'],
      syringeType: map['syringe_type'],
      syringeUnits: map['syringe_units'],
      vialWaterMl: (map['vial_water_ml'] as num).toDouble(),
      vialPeptideMl: (map['vial_peptide_ml'] as num).toDouble(),
      desiredDoseMcg: (map['desired_dose_mcg'] as num).toDouble(),
      resultAmount: (map['result_amount'] as num).toDouble(),
      calculatedAt: DateTime.fromMillisecondsSinceEpoch(map['calculated_at']),
      syncStatus: map['sync_status'] ?? 'pending',
      remoteId: map['remote_id'],
    );
  }

  Map<String, dynamic> toJson() => toMap();

  factory PeptideCalculation.fromJson(Map<String, dynamic> json) => PeptideCalculation.fromMap(json);
}
