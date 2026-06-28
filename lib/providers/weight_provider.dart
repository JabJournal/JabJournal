import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/weight_entry.dart';
import '../services/backup_scheduler.dart';
import '../services/database/database_helper.dart';

/// Manages weight log entries and exposes derived helpers (latest weight,
/// trend vs previous entry, etc.).
class WeightProvider with ChangeNotifier {
  final DatabaseHelper _db;

  /// Dependency is injected for testability. Production callers can omit
  /// the argument; tests pass in a mock.
  WeightProvider({DatabaseHelper? databaseHelper})
      : _db = databaseHelper ?? DatabaseHelper();

  List<WeightEntry> _entries = [];
  bool _isLoading = false;
  String? _error;

  /// All entries, sorted newest-first.
  List<WeightEntry> get entries => List.unmodifiable(_entries);
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// The most recent recorded weight, or null if there are no entries.
  WeightEntry? get latest => _entries.isEmpty ? null : _entries.first;

  /// The entry immediately preceding [latest], or null if fewer than two
  /// entries exist.
  WeightEntry? get previous => _entries.length < 2 ? null : _entries[1];

  /// Difference (latest − previous) in pounds. Negative = weight loss.
  /// Returns null if there's no previous entry to compare against.
  double? get trendLbs {
    final l = latest;
    final p = previous;
    if (l == null || p == null) return null;
    return l.weightLbs - p.weightLbs;
  }

  // ── Loading ─────────────────────────────────────────────────────────────────

  Future<void> loadAll() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _entries = await _db.getAllWeights();
      // The DB query already returns sorted rows, but sort defensively so
      // the [entries] "newest-first" contract holds even if the DB order
      // ever changes.
      _sort();
    } catch (e) {
      _error = 'Error loading weights: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ── CRUD ────────────────────────────────────────────────────────────────────

  Future<String?> addWeight({
    required double weightLbs,
    DateTime? recordedAt,
    String? notes,
    String? doseId,
  }) async {
    try {
      final entry = WeightEntry(
        id: const Uuid().v4(),
        weightLbs: weightLbs,
        recordedAt: recordedAt ?? DateTime.now(),
        notes: notes,
        doseId: doseId,
        syncStatus: 'pending',
      );
      await _db.insertWeight(entry);
      _entries.add(entry);
      _sort();
      _error = null;
      notifyListeners();
      BackupScheduler.instance.scheduleBackup();
      return entry.id;
    } catch (e) {
      _error = 'Error adding weight: $e';
      notifyListeners();
      return null;
    }
  }

  Future<void> updateWeight({
    required String id,
    required double weightLbs,
    required DateTime recordedAt,
    String? notes,
  }) async {
    try {
      final idx = _entries.indexWhere((e) => e.id == id);
      if (idx == -1) throw Exception('Weight entry not found');
      final updated = _entries[idx].copyWith(
        weightLbs: weightLbs,
        recordedAt: recordedAt,
        notes: notes,
        syncStatus: 'pending',
        clearNotes: notes == null,
      );
      await _db.updateWeight(updated);
      _entries[idx] = updated;
      _sort();
      _error = null;
      notifyListeners();
      BackupScheduler.instance.scheduleBackup();
    } catch (e) {
      _error = 'Error updating weight: $e';
      notifyListeners();
    }
  }

  Future<void> deleteWeight(String id) async {
    try {
      await _db.deleteWeight(id);
      _entries.removeWhere((e) => e.id == id);
      _error = null;
      notifyListeners();
      BackupScheduler.instance.scheduleBackup();
    } catch (e) {
      _error = 'Error deleting weight: $e';
      notifyListeners();
    }
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  /// Returns entries within the given date range (inclusive of [from]).
  List<WeightEntry> entriesInRange(DateTime? from) {
    if (from == null) return List.unmodifiable(_entries);
    return _entries.where((e) => !e.recordedAt.isBefore(from)).toList();
  }

  void _sort() {
    _entries.sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
  }
}
