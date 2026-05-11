import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/peptide_calculation.dart';
import '../services/backup_scheduler.dart';
import '../services/database/database_helper.dart';
import '../services/supabase/sync_manager.dart';

class CalculatorProvider with ChangeNotifier {
  final _dbHelper = DatabaseHelper();
  final _syncManager = SyncManager();

  List<PeptideCalculation> _calculations = [];
  bool _isLoading = false;
  String? _error;

  List<PeptideCalculation> get calculations => _calculations;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadCalculations() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _calculations = await _dbHelper.getAllCalculations();
      _error = null;
    } catch (e) {
      _error = 'Error loading calculations: $e';
      debugPrint(_error);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  double calculateDose({
    required String syringeType,
    required int syringeUnits,
    required double vialWaterMl,
    required double vialPeptideMl,
    required double desiredDoseMcg,
  }) {
    final concentration = (vialPeptideMl / vialWaterMl) * 1000;
    final dosePerUnit = concentration / syringeUnits;
    final resultAmount = desiredDoseMcg / dosePerUnit;
    return resultAmount;
  }

  Future<void> saveCalculation({
    required String peptideName,
    required String syringeType,
    required int syringeUnits,
    required double vialWaterMl,
    required double vialPeptideMl,
    required double desiredDoseMcg,
    required double resultAmount,
  }) async {
    try {
      final calculation = PeptideCalculation(
        id: const Uuid().v4(),
        peptideName: peptideName,
        syringeType: syringeType,
        syringeUnits: syringeUnits,
        vialWaterMl: vialWaterMl,
        vialPeptideMl: vialPeptideMl,
        desiredDoseMcg: desiredDoseMcg,
        resultAmount: resultAmount,
        calculatedAt: DateTime.now(),
        syncStatus: 'pending',
      );

      await _dbHelper.insertCalculation(calculation);
      _calculations.insert(0, calculation);
      _error = null;
      notifyListeners();

      _syncManager.syncAll();
      BackupScheduler.instance.scheduleBackup();
    } catch (e) {
      _error = 'Error saving calculation: $e';
      debugPrint(_error);
      notifyListeners();
    }
  }

  Future<void> deleteCalculation(String id) async {
    try {
      await _dbHelper.deleteCalculation(id);
      _calculations.removeWhere((c) => c.id == id);
      _error = null;
      notifyListeners();

      _syncManager.syncAll();
      BackupScheduler.instance.scheduleBackup();
    } catch (e) {
      _error = 'Error deleting calculation: $e';
      debugPrint(_error);
      notifyListeners();
    }
  }

  PeptideCalculation? getCalculationById(String id) {
    try {
      return _calculations.firstWhere((c) => c.id == id);
    } catch (e) {
      return null;
    }
  }

  List<PeptideCalculation> getCalculationsByPeptide(String peptideName) {
    return _calculations.where((c) => c.peptideName == peptideName).toList();
  }
}
