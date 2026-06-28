import 'package:flutter_test/flutter_test.dart';
import 'package:jab_journal/models/weight_entry.dart';
import 'package:jab_journal/providers/weight_provider.dart';
import 'package:jab_journal/services/database/database_helper.dart';
import 'package:mocktail/mocktail.dart';

class _MockDatabaseHelper extends Mock implements DatabaseHelper {}

void main() {
  setUpAll(() {
    registerFallbackValue(WeightEntry(
      id: 'fallback',
      weightLbs: 0,
      recordedAt: DateTime(2020, 1, 1),
    ));
  });

  late _MockDatabaseHelper db;
  late WeightProvider provider;

  WeightEntry entry({
    required String id,
    required DateTime recordedAt,
    double weightLbs = 180,
  }) {
    return WeightEntry(
      id: id,
      weightLbs: weightLbs,
      recordedAt: recordedAt,
    );
  }

  setUp(() {
    db = _MockDatabaseHelper();
    when(() => db.insertWeight(any())).thenAnswer((_) async => 'id');
    when(() => db.updateWeight(any())).thenAnswer((_) async => 1);
    when(() => db.deleteWeight(any())).thenAnswer((_) async => 1);
    provider = WeightProvider(databaseHelper: db);
  });

  void expectSortedNewestFirst(List<WeightEntry> list) {
    for (var i = 1; i < list.length; i++) {
      expect(
        list[i].recordedAt.isBefore(list[i - 1].recordedAt) ||
            list[i].recordedAt.isAtSameMomentAs(list[i - 1].recordedAt),
        isTrue,
        reason:
            'entries[$i] (${list[i].recordedAt}) should be older than entries[${i - 1}] (${list[i - 1].recordedAt})',
      );
    }
  }

  group('chronological ordering', () {
    test('loadAll sorts the list newest-first', () async {
      when(() => db.getAllWeights()).thenAnswer((_) async => [
            entry(id: '1', recordedAt: DateTime(2026, 6, 27)),
            entry(id: '2', recordedAt: DateTime(2026, 6, 29)),
            entry(id: '3', recordedAt: DateTime(2026, 6, 28)),
          ]);
      await provider.loadAll();

      expect(provider.entries.map((e) => e.id).toList(), ['2', '3', '1']);
    });

    test('loadAll sorts even when the DB returns an out-of-order list',
        () async {
      // Simulate a future where the DB query stops sorting for some reason —
      // the provider's defensive sort should still produce a sorted list.
      when(() => db.getAllWeights()).thenAnswer((_) async => [
            entry(id: '3', recordedAt: DateTime(2026, 6, 28)),
            entry(id: '1', recordedAt: DateTime(2026, 6, 27)),
            entry(id: '2', recordedAt: DateTime(2026, 6, 29)),
          ]);
      await provider.loadAll();

      expect(provider.entries.map((e) => e.id).toList(), ['2', '3', '1']);
      expectSortedNewestFirst(provider.entries);
    });

    test('addWeight places a past-dated entry in the correct position',
        () async {
      when(() => db.getAllWeights()).thenAnswer((_) async => [
            entry(id: '1', recordedAt: DateTime(2026, 6, 28)),
            entry(id: '2', recordedAt: DateTime(2026, 6, 29)),
          ]);
      await provider.loadAll();

      final newId = await provider.addWeight(
        weightLbs: 175,
        recordedAt: DateTime(2026, 6, 26), // 3 days ago
      );

      expect(provider.entries.map((e) => e.id).toList(),
          ['2', '1', newId]);
      expectSortedNewestFirst(provider.entries);
    });

    test('updateWeight re-sorts when recordedAt changes', () async {
      when(() => db.getAllWeights()).thenAnswer((_) async => [
            entry(id: '1', recordedAt: DateTime(2026, 6, 25)),
            entry(id: '2', recordedAt: DateTime(2026, 6, 28)),
            entry(id: '3', recordedAt: DateTime(2026, 6, 26)),
          ]);
      await provider.loadAll();

      // Move entry '3' to today.
      await provider.updateWeight(
        id: '3',
        weightLbs: 180,
        recordedAt: DateTime(2026, 6, 29),
      );
      expect(provider.entries.map((e) => e.id).toList(), ['3', '2', '1']);
      expectSortedNewestFirst(provider.entries);
    });

    test('latest returns the most recent entry after sort', () async {
      when(() => db.getAllWeights()).thenAnswer((_) async => [
            entry(id: '1', recordedAt: DateTime(2026, 6, 25)),
            entry(id: '2', recordedAt: DateTime(2026, 6, 29)),
            entry(id: '3', recordedAt: DateTime(2026, 6, 28)),
          ]);
      await provider.loadAll();

      expect(provider.latest?.id, '2');
    });
  });
}
