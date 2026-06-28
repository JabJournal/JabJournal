import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/dose_history.dart';
import '../services/backup_scheduler.dart';
import '../services/database/database_helper.dart';

class DoseHistoryProvider with ChangeNotifier {
  final DatabaseHelper _dbHelper;

  List<DoseHistory> _doses = [];
  bool _isLoading = false;
  String? _error;

  /// DatabaseHelper is injected to make the provider testable. Production
  /// callers can omit the argument; tests pass in a mock.
  DoseHistoryProvider({DatabaseHelper? databaseHelper})
      : _dbHelper = databaseHelper ?? DatabaseHelper();

  List<DoseHistory> get doses => _doses;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadAllDoses() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _doses = await _dbHelper.getAllDoses();
      _sort();
      _error = null;
    } catch (e) {
      _error = 'Error loading doses: $e';
      debugPrint(_error);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadDosesByPeptide(String peptideId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _doses = await _dbHelper.getDosesByPeptide(peptideId);
      _sort();
      _error = null;
    } catch (e) {
      _error = 'Error loading doses: $e';
      debugPrint(_error);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<String?> addDose({
    required String peptideId,
    required double amountMcg,
    DateTime? takenAt,
    String? notes,
    String? injectionSite,
    List<String> sideEffects = const [],
    String? injectionSiteReaction,
    IsrSeverity? isrSeverity,
  }) async {
    try {
      final dose = DoseHistory(
        id: const Uuid().v4(),
        peptideId: peptideId,
        amountMcg: amountMcg,
        takenAt: takenAt ?? DateTime.now(),
        notes: notes,
        injectionSite: injectionSite,
        sideEffects: sideEffects,
        injectionSiteReaction: injectionSiteReaction,
        isrSeverity: isrSeverity,
        syncStatus: 'pending',
      );

      await _dbHelper.insertDose(dose);
      _doses.add(dose);
      // takenAt can be a past date (user logs a dose retroactively), so we
      // can't just prepend — sort to keep the list newest-first.
      _sort();
      _error = null;
      notifyListeners();

      BackupScheduler.instance.scheduleBackup();
      return dose.id;
    } catch (e) {
      _error = 'Error adding dose: $e';
      debugPrint(_error);
      notifyListeners();
      return null;
    }
  }

  Future<void> updateDose({
    required String id,
    required double amountMcg,
    required DateTime takenAt,
    String? notes,
    String? injectionSite,
    List<String> sideEffects = const [],
    String? injectionSiteReaction,
    IsrSeverity? isrSeverity,
  }) async {
    try {
      final index = _doses.indexWhere((d) => d.id == id);
      if (index == -1) throw Exception('Dose not found');

      final updatedDose = _doses[index].copyWith(
        amountMcg: amountMcg,
        takenAt: takenAt,
        notes: notes,
        injectionSite: injectionSite,
        sideEffects: sideEffects,
        injectionSiteReaction: injectionSiteReaction,
        isrSeverity: isrSeverity,
        clearInjectionSite: injectionSite == null,
        clearInjectionSiteReaction: injectionSiteReaction == null,
        clearIsrSeverity: isrSeverity == null,
        clearNotes: notes == null,
        syncStatus: 'pending',
      );

      await _dbHelper.updateDose(updatedDose);
      _doses[index] = updatedDose;
      // takenAt may have changed (e.g. user edited the date to a different
      // day), so re-sort to keep the list newest-first.
      _sort();
      _error = null;
      notifyListeners();

      BackupScheduler.instance.scheduleBackup();
    } catch (e) {
      _error = 'Error updating dose: $e';
      debugPrint(_error);
      notifyListeners();
    }
  }

  Future<void> deleteDose(String id) async {
    try {
      await _dbHelper.deleteDose(id);
      _doses.removeWhere((d) => d.id == id);
      _error = null;
      notifyListeners();

      BackupScheduler.instance.scheduleBackup();
    } catch (e) {
      _error = 'Error deleting dose: $e';
      debugPrint(_error);
      notifyListeners();
    }
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  /// Sorts the in-memory list newest-first by takenAt. The DB query already
  /// returns sorted rows, but mutations (add / update with a different date)
  /// can leave the list out of order — this keeps callers (history list,
  /// dashboard, peptide detail) safe to assume sorted order.
  void _sort() {
    _doses.sort((a, b) => b.takenAt.compareTo(a.takenAt));
  }

  int getDoseCountForPeptide(String peptideId) {
    return _doses.where((d) => d.peptideId == peptideId).length;
  }

  double getTotalMcgForPeptide(String peptideId) {
    return _doses
        .where((d) => d.peptideId == peptideId)
        .fold(0.0, (sum, dose) => sum + dose.amountMcg);
  }

  Map<String, int> getDoseCountByPeptide() {
    final counts = <String, int>{};
    for (final dose in _doses) {
      counts[dose.peptideId] = (counts[dose.peptideId] ?? 0) + 1;
    }
    return counts;
  }

  Map<String, double> getTotalMcgByPeptide() {
    final totals = <String, double>{};
    for (final dose in _doses) {
      totals[dose.peptideId] = (totals[dose.peptideId] ?? 0.0) + dose.amountMcg;
    }
    return totals;
  }

  List<DoseHistory> dosesInRange(DateTime? from) {
    if (from == null) return List.unmodifiable(_doses);
    return _doses.where((d) => !d.takenAt.isBefore(from)).toList();
  }

  /// Returns `{ peptideId: { dayIndex: totalMcg } }` where dayIndex is days
  /// since [rangeStart]. Suitable for feeding directly into a line chart.
  Map<String, Map<int, double>> dailyMcgPerPeptide({
    required DateTime rangeStart,
    DateTime? from,
  }) {
    final doses = dosesInRange(from);
    final result = <String, Map<int, double>>{};
    final startDay =
        DateTime(rangeStart.year, rangeStart.month, rangeStart.day);

    for (final dose in doses) {
      final day =
          DateTime(dose.takenAt.year, dose.takenAt.month, dose.takenAt.day);
      final index = day.difference(startDay).inDays;
      if (index < 0) continue;
      result[dose.peptideId] ??= {};
      result[dose.peptideId]![index] =
          (result[dose.peptideId]![index] ?? 0) + dose.amountMcg;
    }
    return result;
  }
}
