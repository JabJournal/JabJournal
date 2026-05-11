import 'package:sqflite/sqflite.dart';
import '../../models/peptide.dart';
import '../../models/dose_history.dart';
import '../../models/schedule.dart';
import '../../models/peptide_calculation.dart';
import '../../models/weight_entry.dart';
import 'sqlite_service.dart';

class DatabaseHelper {
  final _sqliteService = SQLiteService();

  Future<Database> _getDb() async {
    return _sqliteService.database;
  }

  Future<String> insertPeptide(Peptide peptide) async {
    final db = await _getDb();
    await db.insert('peptides', peptide.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
    return peptide.id;
  }

  Future<Peptide?> getPeptide(String id) async {
    final db = await _getDb();
    final result = await db.query('peptides', where: 'id = ?', whereArgs: [id]);
    if (result.isEmpty) return null;
    return Peptide.fromMap(result.first);
  }

  Future<List<Peptide>> getAllPeptides() async {
    final db = await _getDb();
    final result = await db.query('peptides', orderBy: 'created_at DESC');
    return result.map((map) => Peptide.fromMap(map)).toList();
  }

  Future<int> updatePeptide(Peptide peptide) async {
    final db = await _getDb();
    return db.update('peptides', peptide.toMap(), where: 'id = ?', whereArgs: [peptide.id]);
  }

  Future<int> deletePeptide(String id) async {
    final db = await _getDb();
    return db.delete('peptides', where: 'id = ?', whereArgs: [id]);
  }

  Future<String> insertDose(DoseHistory dose) async {
    final db = await _getDb();
    await db.insert('doses', dose.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
    return dose.id;
  }

  Future<DoseHistory?> getDose(String id) async {
    final db = await _getDb();
    final result = await db.query('doses', where: 'id = ?', whereArgs: [id]);
    if (result.isEmpty) return null;
    return DoseHistory.fromMap(result.first);
  }

  Future<List<DoseHistory>> getDosesByPeptide(String peptideId) async {
    final db = await _getDb();
    final result = await db.query('doses',
        where: 'peptide_id = ?', whereArgs: [peptideId], orderBy: 'taken_at DESC');
    return result.map((map) => DoseHistory.fromMap(map)).toList();
  }

  Future<List<DoseHistory>> getAllDoses() async {
    final db = await _getDb();
    final result = await db.query('doses', orderBy: 'taken_at DESC');
    return result.map((map) => DoseHistory.fromMap(map)).toList();
  }

  Future<int> updateDose(DoseHistory dose) async {
    final db = await _getDb();
    return db.update('doses', dose.toMap(), where: 'id = ?', whereArgs: [dose.id]);
  }

  Future<int> deleteDose(String id) async {
    final db = await _getDb();
    return db.delete('doses', where: 'id = ?', whereArgs: [id]);
  }

  Future<String> insertSchedule(PeptideSchedule schedule) async {
    final db = await _getDb();
    await db.insert('peptide_schedules', schedule.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
    return schedule.id;
  }

  Future<PeptideSchedule?> getSchedule(String id) async {
    final db = await _getDb();
    final result = await db.query('peptide_schedules', where: 'id = ?', whereArgs: [id]);
    if (result.isEmpty) return null;
    return PeptideSchedule.fromMap(result.first);
  }

  Future<List<PeptideSchedule>> getSchedulesByPeptide(String peptideId) async {
    final db = await _getDb();
    final result = await db.query('peptide_schedules',
        where: 'peptide_id = ?', whereArgs: [peptideId]);
    return result.map((map) => PeptideSchedule.fromMap(map)).toList();
  }

  Future<List<PeptideSchedule>> getAllSchedules() async {
    final db = await _getDb();
    final result = await db.query('peptide_schedules');
    return result.map((map) => PeptideSchedule.fromMap(map)).toList();
  }

  Future<int> updateSchedule(PeptideSchedule schedule) async {
    final db = await _getDb();
    return db.update('peptide_schedules', schedule.toMap(),
        where: 'id = ?', whereArgs: [schedule.id]);
  }

  Future<int> deleteSchedule(String id) async {
    final db = await _getDb();
    return db.delete('peptide_schedules', where: 'id = ?', whereArgs: [id]);
  }

  Future<String> insertCalculation(PeptideCalculation calculation) async {
    final db = await _getDb();
    await db.insert('calculations', calculation.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
    return calculation.id;
  }

  Future<PeptideCalculation?> getCalculation(String id) async {
    final db = await _getDb();
    final result =
        await db.query('calculations', where: 'id = ?', whereArgs: [id]);
    if (result.isEmpty) return null;
    return PeptideCalculation.fromMap(result.first);
  }

  Future<List<PeptideCalculation>> getAllCalculations() async {
    final db = await _getDb();
    final result = await db.query('calculations', orderBy: 'calculated_at DESC');
    return result.map((map) => PeptideCalculation.fromMap(map)).toList();
  }

  Future<int> updateCalculation(PeptideCalculation calculation) async {
    final db = await _getDb();
    return db.update('calculations', calculation.toMap(),
        where: 'id = ?', whereArgs: [calculation.id]);
  }

  Future<int> deleteCalculation(String id) async {
    final db = await _getDb();
    return db.delete('calculations', where: 'id = ?', whereArgs: [id]);
  }

  // ── Weight entries ─────────────────────────────────────────────────────────

  Future<String> insertWeight(WeightEntry entry) async {
    final db = await _getDb();
    await db.insert('weight_entries', entry.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
    return entry.id;
  }

  Future<WeightEntry?> getWeight(String id) async {
    final db = await _getDb();
    final result =
        await db.query('weight_entries', where: 'id = ?', whereArgs: [id]);
    if (result.isEmpty) return null;
    return WeightEntry.fromMap(result.first);
  }

  Future<List<WeightEntry>> getAllWeights() async {
    final db = await _getDb();
    final result =
        await db.query('weight_entries', orderBy: 'recorded_at DESC');
    return result.map((map) => WeightEntry.fromMap(map)).toList();
  }

  Future<int> updateWeight(WeightEntry entry) async {
    final db = await _getDb();
    return db.update('weight_entries', entry.toMap(),
        where: 'id = ?', whereArgs: [entry.id]);
  }

  Future<int> deleteWeight(String id) async {
    final db = await _getDb();
    return db.delete('weight_entries', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<dynamic>> getUnsynced(String table) async {
    final db = await _getDb();
    final result = await db.query(table, where: "sync_status != 'synced'");
    return result;
  }

  Future<int> updateSyncStatus(String table, String id, String status) async {
    final db = await _getDb();
    return db.update(table, {'sync_status': status},
        where: 'id = ?', whereArgs: [id]);
  }
}
