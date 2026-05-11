class Peptide {
  final String id;
  final String name;
  final String? description;
  final String? vendor;
  final String? dosageStrength; // e.g., "12mg", "10mg per vial"
  final String? colorHex; // user-chosen color, e.g. "#2196F3"; null = auto from palette
  final String? iconName; // key into kPeptideIcons; null = default science beaker
  final DateTime createdAt;
  final DateTime updatedAt;
  final String syncStatus;
  final String? remoteId;

  Peptide({
    required this.id,
    required this.name,
    this.description,
    this.vendor,
    this.dosageStrength,
    this.colorHex,
    this.iconName,
    required this.createdAt,
    required this.updatedAt,
    this.syncStatus = 'pending',
    this.remoteId,
  });

  Peptide copyWith({
    String? id,
    String? name,
    String? description,
    String? vendor,
    String? dosageStrength,
    String? colorHex,
    String? iconName,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? syncStatus,
    String? remoteId,
    bool clearColorHex = false,
    bool clearIconName = false,
  }) {
    return Peptide(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      vendor: vendor ?? this.vendor,
      dosageStrength: dosageStrength ?? this.dosageStrength,
      colorHex: clearColorHex ? null : (colorHex ?? this.colorHex),
      iconName: clearIconName ? null : (iconName ?? this.iconName),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      syncStatus: syncStatus ?? this.syncStatus,
      remoteId: remoteId ?? this.remoteId,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'vendor': vendor,
      'dosage_strength': dosageStrength,
      'color_hex': colorHex,
      'icon_name': iconName,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
      'sync_status': syncStatus,
      'remote_id': remoteId,
    };
  }

  factory Peptide.fromMap(Map<String, dynamic> map) {
    return Peptide(
      id: map['id'],
      name: map['name'],
      description: map['description'],
      vendor: map['vendor'],
      dosageStrength: map['dosage_strength'],
      colorHex: map['color_hex'],
      iconName: map['icon_name'],
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at']),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at']),
      syncStatus: map['sync_status'] ?? 'pending',
      remoteId: map['remote_id'],
    );
  }

  Map<String, dynamic> toJson() => toMap();

  factory Peptide.fromJson(Map<String, dynamic> json) => Peptide.fromMap(json);
}
