import 'package:flutter_test/flutter_test.dart';
import 'package:jab_journal/models/schedule.dart';

void main() {
  group('ScheduleFrequency', () {
    test('storageKey returns canonical string for each value', () {
      expect(ScheduleFrequency.once.storageKey, 'once');
      expect(ScheduleFrequency.weekly.storageKey, 'weekly');
    });

    test('fromStorage maps known keys', () {
      expect(ScheduleFrequency.fromStorage('once'), ScheduleFrequency.once);
      expect(ScheduleFrequency.fromStorage('weekly'), ScheduleFrequency.weekly);
    });

    test('fromStorage falls back to weekly for unknown / legacy values', () {
      // "custom" was a legacy v1/v2 value that meant the same as weekly.
      expect(ScheduleFrequency.fromStorage('custom'), ScheduleFrequency.weekly);
      expect(ScheduleFrequency.fromStorage(null), ScheduleFrequency.weekly);
      expect(ScheduleFrequency.fromStorage('mystery'), ScheduleFrequency.weekly);
    });
  });

  group('RescheduledOccurrence', () {
    final original = DateTime(2026, 6, 27);
    final newDt = DateTime(2026, 6, 28, 10, 30);
    final entry = RescheduledOccurrence(
      originalDate: original,
      newDateTime: newDt,
      replacesExistingOnNewDay: true,
    );

    test('toMap / fromMap round-trip preserves all fields', () {
      final map = entry.toMap();
      final restored = RescheduledOccurrence.fromMap(map);
      expect(restored.originalDate, original);
      expect(restored.newDateTime, newDt);
      expect(restored.replacesExistingOnNewDay, isTrue);
    });

    test('toMap stores the replacesExistingOnNewDay flag as 0/1', () {
      final keepBoth = RescheduledOccurrence(
        originalDate: original,
        newDateTime: newDt,
      );
      final replace = entry; // replacesExistingOnNewDay: true
      expect(keepBoth.toMap()['replaces_existing_on_new_day'], 0);
      expect(replace.toMap()['replaces_existing_on_new_day'], 1);
    });

    test('fromMap defaults replacesExistingOnNewDay to false when missing', () {
      // Older serializations (or hand-crafted maps) may omit the flag.
      final restored = RescheduledOccurrence.fromMap({
        'original_date': original.millisecondsSinceEpoch,
        'new_date_time': newDt.millisecondsSinceEpoch,
      });
      expect(restored.replacesExistingOnNewDay, isFalse);
    });

    test('copyWith only overrides the supplied fields', () {
      final updated = entry.copyWith(newDateTime: newDt.add(const Duration(hours: 1)));
      expect(updated.originalDate, original);
      expect(updated.newDateTime, newDt.add(const Duration(hours: 1)));
      expect(updated.replacesExistingOnNewDay, isTrue);
    });
  });

  group('PeptideSchedule — reschedule helpers', () {
    final base = PeptideSchedule(
      id: 'sched-1',
      peptideId: 'pep-1',
      frequency: ScheduleFrequency.weekly,
      daysOfWeek: const [1, 3, 5], // Mon, Wed, Fri
      timeOfDay: 10 * 3600, // 10:00
    );

    PeptideSchedule withReschedules(List<RescheduledOccurrence> entries) =>
        base.copyWith(rescheduledOccurrences: entries);

    test('isOccurrenceRescheduled is true on the original day, false elsewhere',
        () {
      final mondayToWednesday = RescheduledOccurrence(
        originalDate: DateTime(2026, 6, 29), // Monday
        newDateTime: DateTime(2026, 7, 1, 10), // Wednesday 10:00
      );
      final s = withReschedules([mondayToWednesday]);

      expect(s.isOccurrenceRescheduled(DateTime(2026, 6, 29)), isTrue);
      expect(s.isOccurrenceRescheduled(DateTime(2026, 6, 30)), isFalse);
      expect(s.isOccurrenceRescheduled(DateTime(2026, 7, 1)), isFalse);
    });

    test('rescheduleTarget returns the new fire time for the original day', () {
      final target = DateTime(2026, 7, 1, 10);
      final s = withReschedules([
        RescheduledOccurrence(
          originalDate: DateTime(2026, 6, 29),
          newDateTime: target,
        ),
      ]);
      expect(s.rescheduleTarget(DateTime(2026, 6, 29)), target);
      expect(s.rescheduleTarget(DateTime(2026, 6, 30)), isNull);
    });

    test('rescheduleToDate finds the entry that lands on a given day', () {
      final original = DateTime(2026, 6, 29);
      final target = DateTime(2026, 7, 1, 10);
      final s = withReschedules([
        RescheduledOccurrence(originalDate: original, newDateTime: target),
      ]);
      expect(s.rescheduleToDate(DateTime(2026, 7, 1)), isNotNull);
      expect(s.rescheduleToDate(DateTime(2026, 7, 1))!.originalDate, original);
      expect(s.rescheduleToDate(DateTime(2026, 7, 2)), isNull);
    });

    test('rescheduleOriginal returns the source for the new day', () {
      final original = DateTime(2026, 6, 29);
      final s = withReschedules([
        RescheduledOccurrence(
          originalDate: original,
          newDateTime: DateTime(2026, 7, 1, 10),
        ),
      ]);
      expect(s.rescheduleOriginal(DateTime(2026, 7, 1)), original);
      expect(s.rescheduleOriginal(DateTime(2026, 6, 29)), isNull);
    });

    test('isOccurrenceReplaced is true only when the new day has the flag set',
        () {
      final target = DateTime(2026, 7, 1, 10);
      final keepBoth = withReschedules([
        RescheduledOccurrence(
          originalDate: DateTime(2026, 6, 29),
          newDateTime: target,
        ),
      ]);
      final replace = withReschedules([
        RescheduledOccurrence(
          originalDate: DateTime(2026, 6, 29),
          newDateTime: target,
          replacesExistingOnNewDay: true,
        ),
      ]);

      expect(keepBoth.isOccurrenceReplaced(DateTime(2026, 7, 1)), isFalse);
      expect(replace.isOccurrenceReplaced(DateTime(2026, 7, 1)), isTrue);
    });

    test('rescheduleForOriginalDate returns the entry or null', () {
      final entry = RescheduledOccurrence(
        originalDate: DateTime(2026, 6, 29),
        newDateTime: DateTime(2026, 7, 1, 10),
      );
      final s = withReschedules([entry]);
      expect(s.rescheduleForOriginalDate(DateTime(2026, 6, 29)), entry);
      expect(s.rescheduleForOriginalDate(DateTime(2026, 6, 30)), isNull);
    });

    test('clearReschedulesForDate removes entries that touch the date', () {
      final s = withReschedules([
        RescheduledOccurrence(
          originalDate: DateTime(2026, 6, 29),
          newDateTime: DateTime(2026, 7, 1, 10),
        ),
        RescheduledOccurrence(
          originalDate: DateTime(2026, 6, 30),
          newDateTime: DateTime(2026, 7, 2, 10),
        ),
      ]);
      // Mutates the list in place; rescheduleForOriginalDate should now miss.
      s.clearReschedulesForDate(DateTime(2026, 6, 29));
      expect(s.rescheduleForOriginalDate(DateTime(2026, 6, 29)), isNull);
      expect(s.rescheduleForOriginalDate(DateTime(2026, 6, 30)), isNotNull);
      // Also clear by the target date.
      s.clearReschedulesForDate(DateTime(2026, 7, 2));
      expect(s.rescheduledOccurrences, isEmpty);
    });
  });

  group('PeptideSchedule — isExpired / isOccurrenceCompleted', () {
    test('once schedule is expired when its specific date is in the past', () {
      final s = PeptideSchedule(
        id: 'a',
        peptideId: 'p',
        frequency: ScheduleFrequency.once,
        timeOfDay: 3600,
        specificDate: DateTime(2020, 1, 1),
      );
      expect(s.isExpired(now: DateTime(2026, 6, 27)), isTrue);
    });

    test('once schedule is not expired when its specific date is today', () {
      final today = DateTime(2026, 6, 27, 9);
      final s = PeptideSchedule(
        id: 'a',
        peptideId: 'p',
        frequency: ScheduleFrequency.once,
        timeOfDay: 3600,
        specificDate: today,
      );
      expect(s.isExpired(now: today), isFalse);
    });

    test('weekly schedule is expired only when endDate is in the past', () {
      final s = PeptideSchedule(
        id: 'a',
        peptideId: 'p',
        frequency: ScheduleFrequency.weekly,
        daysOfWeek: const [1],
        timeOfDay: 3600,
        endDate: DateTime(2020, 1, 1),
      );
      expect(s.isExpired(now: DateTime(2026, 6, 27)), isTrue);
    });

    test('isOccurrenceCompleted matches ISO date keys', () {
      final s = PeptideSchedule(
        id: 'a',
        peptideId: 'p',
        frequency: ScheduleFrequency.weekly,
        daysOfWeek: const [1],
        timeOfDay: 3600,
        completedOccurrences: const ['2026-06-29'],
      );
      expect(s.isOccurrenceCompleted(DateTime(2026, 6, 29)), isTrue);
      expect(s.isOccurrenceCompleted(DateTime(2026, 6, 30)), isFalse);
    });
  });

  group('PeptideSchedule — serialization round-trip', () {
    test('toMap / fromMap preserves rescheduledOccurrences and other fields',
        () {
      final s = PeptideSchedule(
        id: 'sched-1',
        peptideId: 'pep-1',
        frequency: ScheduleFrequency.weekly,
        daysOfWeek: const [1, 3, 5],
        timeOfDay: 10 * 3600,
        enabled: true,
        endDate: DateTime(2026, 12, 31),
        completedOccurrences: const ['2026-06-29'],
        rescheduledOccurrences: [
          RescheduledOccurrence(
            originalDate: DateTime(2026, 6, 29),
            newDateTime: DateTime(2026, 7, 1, 10),
            replacesExistingOnNewDay: true,
          ),
        ],
        syncStatus: 'pending',
        remoteId: null,
      );

      final restored = PeptideSchedule.fromMap(s.toMap());
      expect(restored.id, s.id);
      expect(restored.peptideId, s.peptideId);
      expect(restored.frequency, s.frequency);
      expect(restored.daysOfWeek, s.daysOfWeek);
      expect(restored.timeOfDay, s.timeOfDay);
      expect(restored.enabled, s.enabled);
      expect(restored.endDate, s.endDate);
      expect(restored.completedOccurrences, s.completedOccurrences);
      expect(restored.rescheduledOccurrences.length, 1);
      expect(
        restored.rescheduledOccurrences.first.originalDate,
        s.rescheduledOccurrences.first.originalDate,
      );
      expect(
        restored.rescheduledOccurrences.first.newDateTime,
        s.rescheduledOccurrences.first.newDateTime,
      );
      expect(
        restored.rescheduledOccurrences.first.replacesExistingOnNewDay,
        isTrue,
      );
    });

    test('fromMap tolerates a missing rescheduled_occurrences column', () {
      // Pre-v7 rows won't have the column. fromMap should default to empty.
      final restored = PeptideSchedule.fromMap({
        'id': 'a',
        'peptide_id': 'p',
        'frequency': 'weekly',
        'days_of_week': '[]',
        'time_of_day': 3600,
        'enabled': 1,
      });
      expect(restored.rescheduledOccurrences, isEmpty);
    });

    test('copyWith preserves the list reference when not overridden', () {
      final s = PeptideSchedule(
        id: 'a',
        peptideId: 'p',
        timeOfDay: 3600,
        rescheduledOccurrences: [
          RescheduledOccurrence(
            originalDate: DateTime(2026, 6, 29),
            newDateTime: DateTime(2026, 7, 1, 10),
          ),
        ],
      );
      final copy = s.copyWith(timeOfDay: 7200);
      expect(copy.rescheduledOccurrences, s.rescheduledOccurrences);
    });
  });
}
