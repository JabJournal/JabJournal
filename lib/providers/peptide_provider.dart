import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/peptide.dart';
import '../services/backup_scheduler.dart';
import '../services/database/database_helper.dart';

class PeptideProvider with ChangeNotifier {
  final _dbHelper = DatabaseHelper();

  List<Peptide> _peptides = [];
  bool _isLoading = false;
  String? _error;

  List<Peptide> get peptides => _peptides;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadPeptides() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _peptides = await _dbHelper.getAllPeptides();
      _error = null;
    } catch (e) {
      _error = 'Error loading peptides: $e';
      debugPrint(_error);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addPeptide({
    required String name,
    String? description,
    String? vendor,
    String? dosageStrength,
    String? colorHex,
    String? iconName,
  }) async {
    try {
      final peptide = Peptide(
        id: const Uuid().v4(),
        name: name,
        description: description,
        vendor: vendor,
        dosageStrength: dosageStrength,
        colorHex: colorHex,
        iconName: iconName,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        syncStatus: 'pending',
      );

      await _dbHelper.insertPeptide(peptide);
      _peptides.add(peptide);
      _error = null;
      notifyListeners();

      BackupScheduler.instance.scheduleBackup();
    } catch (e) {
      _error = 'Error adding peptide: $e';
      debugPrint(_error);
      notifyListeners();
    }
  }

  Future<void> updatePeptide({
    required String id,
    required String name,
    String? description,
    String? vendor,
    String? dosageStrength,
    String? colorHex,
    String? iconName,
    bool clearColorHex = false,
    bool clearIconName = false,
  }) async {
    try {
      final index = _peptides.indexWhere((p) => p.id == id);
      if (index == -1) throw Exception('Peptide not found');

      final updatedPeptide = _peptides[index].copyWith(
        name: name,
        description: description,
        vendor: vendor,
        dosageStrength: dosageStrength,
        colorHex: colorHex,
        iconName: iconName,
        clearColorHex: clearColorHex,
        clearIconName: clearIconName,
        updatedAt: DateTime.now(),
        syncStatus: 'pending',
      );

      await _dbHelper.updatePeptide(updatedPeptide);
      _peptides[index] = updatedPeptide;
      _error = null;
      notifyListeners();

      BackupScheduler.instance.scheduleBackup();
    } catch (e) {
      _error = 'Error updating peptide: $e';
      debugPrint(_error);
      notifyListeners();
    }
  }

  Future<void> deletePeptide(String id) async {
    try {
      await _dbHelper.deletePeptide(id);
      _peptides.removeWhere((p) => p.id == id);
      _error = null;
      notifyListeners();

      BackupScheduler.instance.scheduleBackup();
    } catch (e) {
      _error = 'Error deleting peptide: $e';
      debugPrint(_error);
      notifyListeners();
    }
  }

  Peptide? getPeptideById(String id) {
    try {
      return _peptides.firstWhere((p) => p.id == id);
    } catch (e) {
      return null;
    }
  }
}
