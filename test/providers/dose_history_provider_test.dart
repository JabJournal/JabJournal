import 'package:flutter_test/flutter_test.dart';
import 'package:jab_journal/models/dose_history.dart';
import 'package:jab_journal/providers/dose_history_provider.dart';
import 'package:jab_journal/services/database/database_helper.dart';
import 'package:mocktail/mocktail.dart';

class _MockDatabaseHelper extends Mock implements DatabaseHelper {}

void main() {
  setUpAll(() {
    registerFallbackValue(DoseHistory(
      id: 'fallback',
      peptideId: 'fallback',
      amountMcg: 0,
      takenAt: DateTime(2020, 1, 1),
    ));
  });

  late _MockDatabaseHelper db;
  late DoseHistoryProvider provider;

  DoseHistory dose({
    required String id,
    required DateTime takenAt,
    String peptideId = 'pep-1',
    double amountMcg = 100,
  }) {
    return DoseHistory(
      id: id,
      peptideId: peptideId,
      amountMcg: amountMcg,
      takenAt: takenAt,
    );
  }

  setUp(() {
    db = _MockDatabaseHelper();
    when(() => db.insertDose(any())).thenAnswer((_) async => 'id');
    when(() => db.updateDose(any())).thenAnswer((_) async => 1);
    when(() => db.deleteDose(any())).thenAnswer((_) async => 1);
    provider = DoseHistoryProvider(databaseHelper: db);
  });

  void expectSortedNewestFirst(List<DoseHistory> list) {
    for (var i = 1; i < list.length; i++) {
      expect(
        list[i].takenAt.isBefore(list[i - 1].takenAt) ||
            list[i].takenAt.isAtSameMomentAs(list[i - 1].takenAt),
        isTrue,
        reason: 'doses[$i] (${list[i].takenAt}) should be older than doses[${i - 1}] (${list[i - 1].takenAt})',
      );
    }
  }

  group('chronological ordering', () {
    test('loadAllDoses sorts the list newest-first', () async {
      when(() => db.getAllDoses()).thenAnswer((_) async => [
            dose(id: '1', takenAt: DateTime(2026, 6, 27)),
            dose(id: '2', takenAt: DateTime(2026, 6, 29)),
            dose(id: '3', takenAt: DateTime(2026, 6, 28)),
          ]);
      await provider.loadAllDoses();

      expect(provider.doses.map((d) => d.id).toList(), ['2', '3', '1']);
    });

    test('loadDosesByPeptide also sorts', () async {
      when(() => db.getDosesByPeptide(any())).thenAnswer((_) async => [
            dose(id: '1', takenAt: DateTime(2026, 6, 27)),
            dose(id: '2', takenAt: DateTime(2026, 6, 29)),
            dose(id: '3', takenAt: DateTime(2026, 6, 28)),
          ]);
      await provider.loadDosesByPeptide('pep-1');

      expect(provider.doses.map((d) => d.id).toList(), ['2', '3', '1']);
    });

    test('addDose places a past-dated dose in the correct chronological position',
        () async {
      // Start with two doses, both today and yesterday.
      when(() => db.getAllDoses()).thenAnswer((_) async => [
            dose(id: '1', takenAt: DateTime(2026, 6, 28, 9)), // yesterday
            dose(id: '2', takenAt: DateTime(2026, 6, 29, 9)), // today
          ]);
      await provider.loadAllDoses();

      // Add a dose dated 3 days ago.
      final result = await provider.addDose(
        peptideId: 'pep-1',
        amountMcg: 250,
        takenAt: DateTime(2026, 6, 26, 9), // 3 days ago
      );

      expect(result, isNotNull);
      // The new dose lands at the END of the sorted list (oldest).
      expect(provider.doses.last.takenAt, DateTime(2026, 6, 26, 9));
      expect(provider.doses.map((d) => d.id).toList(),
          ['2', '1', result]);
      expectSortedNewestFirst(provider.doses);
    });

    test('addDose with today\'s date places it at the top', () async {
      when(() => db.getAllDoses()).thenAnswer((_) async => [
            dose(id: '1', takenAt: DateTime(2026, 6, 27)),
            dose(id: '2', takenAt: DateTime(2026, 6, 26)),
          ]);
      await provider.loadAllDoses();

      final newId = await provider.addDose(
        peptideId: 'pep-1',
        amountMcg: 100,
        takenAt: DateTime(2026, 6, 28, 9),
      );

      expect(provider.doses.first.id, newId);
      expectSortedNewestFirst(provider.doses);
    });

    test('updateDose re-sorts when takenAt changes to a different day',
        () async {
      when(() => db.getAllDoses()).thenAnswer((_) async => [
            dose(id: '1', takenAt: DateTime(2026, 6, 25)),
            dose(id: '2', takenAt: DateTime(2026, 6, 28)),
            dose(id: '3', takenAt: DateTime(2026, 6, 26)),
          ]);
      await provider.loadAllDoses();
      // Sanity: starts sorted.
      expect(provider.doses.map((d) => d.id).toList(), ['2', '3', '1']);

      // Move dose '3' to today (newest), should jump to the top.
      await provider.updateDose(
        id: '3',
        amountMcg: 100,
        takenAt: DateTime(2026, 6, 29),
      );
      expect(provider.doses.map((d) => d.id).toList(), ['3', '2', '1']);
      expectSortedNewestFirst(provider.doses);
    });

    test('updateDose leaves order intact when takenAt does not change',
        () async {
      when(() => db.getAllDoses()).thenAnswer((_) async => [
            dose(id: '1', takenAt: DateTime(2026, 6, 25)),
            dose(id: '2', takenAt: DateTime(2026, 6, 28)),
            dose(id: '3', takenAt: DateTime(2026, 6, 26)),
          ]);
      await provider.loadAllDoses();

      // Just change the notes; takenAt unchanged.
      await provider.updateDose(
        id: '2',
        amountMcg: 200,
        takenAt: DateTime(2026, 6, 28),
        notes: 'updated',
      );
      expect(provider.doses.map((d) => d.id).toList(), ['2', '3', '1']);
    });

    test('deleteDose preserves order of the remaining doses', () async {
      when(() => db.getAllDoses()).thenAnswer((_) async => [
            dose(id: '1', takenAt: DateTime(2026, 6, 25)),
            dose(id: '2', takenAt: DateTime(2026, 6, 28)),
            dose(id: '3', takenAt: DateTime(2026, 6, 26)),
          ]);
      await provider.loadAllDoses();

      await provider.deleteDose('2');
      expect(provider.doses.map((d) => d.id).toList(), ['3', '1']);
    });
  });
}
