import 'package:flutter/material.dart';
import '../models/peptide.dart';

const kPeptideColorPalette = [
  Color(0xFF2196F3), // blue
  Color(0xFF4CAF50), // green
  Color(0xFFFF9800), // orange
  Color(0xFF9C27B0), // purple
  Color(0xFFF44336), // red
  Color(0xFF00BCD4), // cyan
  Color(0xFFFF5722), // deep orange
  Color(0xFF8BC34A), // light green
  Color(0xFFE91E63), // pink
  Color(0xFF009688), // teal
  Color(0xFF3F51B5), // indigo
  Color(0xFFFFC107), // amber
];

/// Returns the palette color for [index], cycling when index exceeds palette length.
Color peptideColor(int index) =>
    kPeptideColorPalette[index % kPeptideColorPalette.length];

/// Returns the peptide's custom color if set, otherwise the palette color for [index].
Color resolvedColor(Peptide peptide, int index) {
  final hex = peptide.colorHex;
  if (hex != null && hex.isNotEmpty) return hexToColor(hex);
  return peptideColor(index);
}

/// Converts a [Color] to a 6-digit uppercase hex string like `"#2196F3"`.
String colorToHex(Color color) {
  return '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';
}

/// Parses `"#2196F3"` or `"2196F3"` to a [Color].
Color hexToColor(String hex) {
  final cleaned = hex.replaceFirst('#', '');
  return Color(int.parse(cleaned, radix: 16) | 0xFF000000);
}

// ─── Peptide icons ────────────────────────────────────────────────────────────

/// Ordered map of icon keys → [IconData].  Keys are stored in the database.
const kPeptideIcons = <String, IconData>{
  'science': Icons.science,
  'medication': Icons.medication,
  'vaccine': Icons.vaccines,
  'biotech': Icons.biotech,
  'pharmacy': Icons.local_pharmacy,
  'fitness': Icons.fitness_center,
  'favorite': Icons.favorite,
  'healing': Icons.healing,
  'bolt': Icons.bolt,
  'water_drop': Icons.water_drop,
  'spa': Icons.spa,
  'monitor_heart': Icons.monitor_heart,
  'psychology': Icons.psychology,
  'star': Icons.star,
  'shield': Icons.shield,
  'nutrition': Icons.egg_alt,
};

/// Returns the [IconData] for [name], falling back to the default beaker.
IconData peptideIconData(String? name) =>
    kPeptideIcons[name] ?? Icons.science;
