import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import '../../models/peptide.dart';
import '../../models/dose_history.dart';
import '../../models/schedule.dart';
import '../../models/peptide_calculation.dart';
import '../database/database_helper.dart';
import 'supabase_service.dart';

class SyncManager {
  final _connectivity = Connectivity();
  final _dbHelper = DatabaseHelper();
  final _supabaseService = SupabaseService();
  bool _isSyncing = false;

  Stream<bool> get connectionStatus {
    return _connectivity.onConnectivityChanged.map((results) {
      return results.any((r) => r != ConnectivityResult.none);
    });
  }

  Future<bool> isOnline() async {
    final results = await _connectivity.checkConnectivity();
    return results.any((r) => r != ConnectivityResult.none);
  }

  Future<void> syncAll() async {
    if (_isSyncing) return;

    _isSyncing = true;
    try {
      if (!await isOnline()) {
        debugPrint('Device is offline, skipping sync');
        return;
      }

      await _syncTable('peptides');
      await _syncTable('doses');
      await _syncTable('peptide_schedules');
      await _syncTable('calculations');
    } finally {
      _isSyncing = false;
    }
  }

  Future<void> _syncTable(String table) async {
    try {
      final unsyncedRecords = await _dbHelper.getUnsynced(table);

      for (final record in unsyncedRecords) {
        try {
          await _syncRecord(table, record);
          await _dbHelper.updateSyncStatus(table, record['id'], 'synced');
        } catch (e) {
          debugPrint('Error syncing record $record: $e');
          await _dbHelper.updateSyncStatus(table, record['id'], 'failed');
        }
      }
    } catch (e) {
      debugPrint('Error syncing table $table: $e');
    }
  }

  Future<void> _syncRecord(String table, Map<String, dynamic> record) async {
    switch (table) {
      case 'peptides':
        await _supabaseService.updatePeptide(
          _peptideFromMap(record),
        );
        break;
      case 'doses':
        await _supabaseService.updateDose(
          _doseFromMap(record),
        );
        break;
      case 'peptide_schedules':
        await _supabaseService.updateSchedule(
          _scheduleFromMap(record),
        );
        break;
      case 'calculations':
        await _supabaseService.insertCalculation(
          _calculationFromMap(record),
        );
        break;
    }
  }

  Peptide _peptideFromMap(Map<String, dynamic> map) => Peptide.fromMap(map);

  DoseHistory _doseFromMap(Map<String, dynamic> map) =>
      DoseHistory.fromMap(map);

  PeptideSchedule _scheduleFromMap(Map<String, dynamic> map) =>
      PeptideSchedule.fromMap(map);

  PeptideCalculation _calculationFromMap(Map<String, dynamic> map) =>
      PeptideCalculation.fromMap(map);
}
