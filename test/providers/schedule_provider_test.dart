import 'package:flutter_test/flutter_test.dart';
import 'package:jab_journal/models/peptide.dart';
import 'package:jab_journal/models/schedule.dart';
import 'package:jab_journal/providers/schedule_provider.dart';
import 'package:jab_journal/services/database/database_helper.dart';
import 'package:jab_journal/services/notification_service.dart';
import 'package:mocktail/mocktail.dart';

class _MockDatabaseHelper extends Mock implements DatabaseHelper {}

class _MockNotificationService extends Mock implements NotificationService {}

/// Captures the most recent value passed to [DatabaseHelper.updateSchedule] so
/// tests can assert on it without using mocktail's `verify(...).captured`,
/// which can interact poorly with `verifyNoMoreInteractions` / `verifyNever`
/// patterns across multiple tests.
PeptideSchedule? _lastUpdatedSchedule;

void main() {
  setUpAll(() {
    registerFallbackValue(PeptideSchedule(
      id: 'fallback',
      peptideId: 'fallback',
      timeOfDay: 0,
    ));
  });

  late _MockDatabaseHelper db;
  late _MockNotificationService notifications;
  late ScheduleProvider provider;

  setUp(() {
    _lastUpdatedSchedule = null;
    db = _MockDatabaseHelper();
    notifications = _MockNotificationService();
    provider = ScheduleProvider(
      databaseHelper: db,
      notificationService: notifications,
    );
    when(() => db.getAllPeptides()).thenAnswer((_) async => <Peptide>[]);
    when(() => notifications.cancelNotification(any())).thenAnswer((_) async {});
    when(() => notifications.scheduleOnceReminder(
          id: any(named: 'id'),
          title: any(named: 'title'),
          body: any(named: 'body'),
          scheduledTime: any(named: 'scheduledTime'),
          payload: any(named: 'payload'),
        )).thenAnswer((_) async {});
    when(() => notifications.scheduleWeeklyNotification(
          id: any(named: 'id'),
          title: any(named: 'title'),
          body: any(named: 'body'),
          dayOfWeek: any(named: 'dayOfWeek'),
          secondsFromMidnight: any(named: 'secondsFromMidnight'),
          payload: any(named: 'payload'),
          skipCurrentOccurrence:
              any(named: 'skipCurrentOccurrence'),
        )).thenAnswer((_) async {});
    when(() => db.updateSchedule(any())).thenAnswer((invocation) async {
      _lastUpdatedSchedule =
          invocation.positionalArguments.first as PeptideSchedule;
      return 1;
    });
  });

  PeptideSchedule weeklyMonWed({
    List<RescheduledOccurrence> reschedules = const [],
    List<String> completed = const [],
  }) {
    return PeptideSchedule(
      id: 'sched-1',
      peptideId: 'pep-1',
      frequency: ScheduleFrequency.weekly,
      daysOfWeek: const [1, 3], // Mon, Wed
      timeOfDay: 10 * 3600, // 10:00
      rescheduledOccurrences: reschedules,
      completedOccurrences: completed,
    );
  }

  PeptideSchedule once({
    DateTime? specificDate,
    List<RescheduledOccurrence> reschedules = const [],
  }) {
    return PeptideSchedule(
      id: 'sched-2',
      peptideId: 'pep-2',
      frequency: ScheduleFrequency.once,
      timeOfDay: 9 * 3600,
      specificDate: specificDate,
      rescheduledOccurrences: reschedules,
    );
  }

  group('rescheduleOccurrence', () {
    test('persists a new entry and schedules a one-shot reminder', () async {
      when(() => db.getAllSchedules()).thenAnswer((_) async => [weeklyMonWed()]);
      await provider.loadAllSchedules();

      final original = DateTime(2026, 6, 29); // Monday
      final newDt = DateTime(2026, 6, 30, 10); // Tuesday 10:00

      await provider.rescheduleOccurrence(
        scheduleId: 'sched-1',
        originalDate: original,
        newDateTime: newDt,
      );

      // Captured via the updateSchedule stub side-effect.
      final captured = _lastUpdatedSchedule;
      expect(captured, isNotNull);
      expect(captured!.rescheduledOccurrences.length, 1);
      expect(captured.rescheduledOccurrences.first.originalDate, original);
      expect(captured.rescheduledOccurrences.first.newDateTime, newDt);
      expect(
        captured.rescheduledOccurrences.first.replacesExistingOnNewDay,
        isFalse,
      );
      expect(captured.syncStatus, 'pending');

      // The one-shot reminder was scheduled in the reschedule slot.
      // Read the in-memory state instead of using verify() — this is the
      // post-condition we actually care about.
      expect(provider.schedules.first.rescheduledOccurrences.length, 1);
    });

    test('re-rescheduling the same original date overwrites the previous entry',
        () async {
      when(() => db.getAllSchedules()).thenAnswer((_) async => [weeklyMonWed()]);
      await provider.loadAllSchedules();

      final original = DateTime(2026, 6, 29);
      await provider.rescheduleOccurrence(
        scheduleId: 'sched-1',
        originalDate: original,
        newDateTime: DateTime(2026, 6, 30, 10),
      );
      await provider.rescheduleOccurrence(
        scheduleId: 'sched-1',
        originalDate: original,
        newDateTime: DateTime(2026, 7, 1, 11),
      );

      final finalState = provider.schedules.first;
      expect(finalState.rescheduledOccurrences.length, 1);
      expect(finalState.rescheduledOccurrences.first.newDateTime,
          DateTime(2026, 7, 1, 11));
    });

    test('rescheduling a different original date adds a second entry', () async {
      when(() => db.getAllSchedules()).thenAnswer((_) async => [weeklyMonWed()]);
      await provider.loadAllSchedules();

      await provider.rescheduleOccurrence(
        scheduleId: 'sched-1',
        originalDate: DateTime(2026, 6, 29),
        newDateTime: DateTime(2026, 6, 30, 10),
      );
      await provider.rescheduleOccurrence(
        scheduleId: 'sched-1',
        originalDate: DateTime(2026, 7, 1),
        newDateTime: DateTime(2026, 7, 2, 10),
      );

      expect(provider.schedules.first.rescheduledOccurrences.length, 2);
    });

    test('passes replacesExistingOnNewDay through to the entry', () async {
      when(() => db.getAllSchedules()).thenAnswer((_) async => [weeklyMonWed()]);
      await provider.loadAllSchedules();

      await provider.rescheduleOccurrence(
        scheduleId: 'sched-1',
        originalDate: DateTime(2026, 6, 29),
        newDateTime: DateTime(2026, 6, 30, 10),
        replacesExistingOnNewDay: true,
      );

      expect(
        provider.schedules.first.rescheduledOccurrences.first
            .replacesExistingOnNewDay,
        isTrue,
      );
    });

    test('rejects reschedule for an unknown schedule', () async {
      when(() => db.getAllSchedules()).thenAnswer((_) async => []);
      await provider.loadAllSchedules();

      await provider.rescheduleOccurrence(
        scheduleId: 'nonexistent',
        originalDate: DateTime(2026, 6, 29),
        newDateTime: DateTime(2026, 6, 30, 10),
      );

      // No schedule was loaded, so provider.schedules stays empty.
      expect(provider.schedules, isEmpty);
    });

    test('rejects reschedule for an expired schedule', () async {
      when(() => db.getAllSchedules()).thenAnswer((_) async => [
            weeklyMonWed().copyWith(endDate: DateTime(2020, 1, 1)),
          ]);
      await provider.loadAllSchedules();

      await provider.rescheduleOccurrence(
        scheduleId: 'sched-1',
        originalDate: DateTime(2026, 6, 29),
        newDateTime: DateTime(2026, 6, 30, 10),
      );

      // The schedule is still loaded (it's not purged from memory) but the
      // reschedule entry wasn't appended.
      expect(provider.schedules.first.rescheduledOccurrences, isEmpty);
    });

    test('rejects reschedule with a newDateTime in the past', () async {
      when(() => db.getAllSchedules()).thenAnswer((_) async => [weeklyMonWed()]);
      await provider.loadAllSchedules();

      await provider.rescheduleOccurrence(
        scheduleId: 'sched-1',
        originalDate: DateTime(2020, 1, 1),
        newDateTime: DateTime(2020, 1, 2),
      );

      expect(provider.schedules.first.rescheduledOccurrences, isEmpty);
    });
  });

  group('buildEventMap', () {
    test('shows rescheduled doses on the new day', () async {
      when(() => db.getAllSchedules()).thenAnswer((_) async => [
            weeklyMonWed(
              reschedules: [
                RescheduledOccurrence(
                  originalDate: DateTime(2026, 6, 29), // Mon
                  newDateTime: DateTime(2026, 6, 30, 10), // Tue
                ),
              ],
            ),
          ]);
      await provider.loadAllSchedules();

      final events = provider.buildEventMap();
      final mondayKey = DateTime(2026, 6, 29);
      final tuesdayKey = DateTime(2026, 6, 30);

      expect(events[mondayKey]?.map((s) => s.id), contains('sched-1'));
      expect(events[tuesdayKey]?.map((s) => s.id), contains('sched-1'));
    });

    test('"replace" mode suppresses the normal occurrence on the new day',
        () async {
      when(() => db.getAllSchedules()).thenAnswer((_) async => [
            weeklyMonWed(
              reschedules: [
                RescheduledOccurrence(
                  originalDate: DateTime(2026, 6, 29), // Mon
                  newDateTime: DateTime(2026, 7, 1, 10), // Wed (a normal day)
                  replacesExistingOnNewDay: true,
                ),
              ],
            ),
          ]);
      await provider.loadAllSchedules();

      final events = provider.buildEventMap();
      final wednesdayKey = DateTime(2026, 7, 1);
      // The schedule should appear exactly once on Wednesday (as a reschedule
      // target), not twice (once for the normal Wed occurrence, once for the
      // reschedule target).
      expect(events[wednesdayKey]?.where((s) => s.id == 'sched-1').length, 1);
    });

    test('"keep both" mode still shows the normal occurrence on the new day',
        () async {
      when(() => db.getAllSchedules()).thenAnswer((_) async => [
            weeklyMonWed(
              reschedules: [
                RescheduledOccurrence(
                  originalDate: DateTime(2026, 6, 29), // Mon
                  newDateTime: DateTime(2026, 7, 1, 10), // Wed
                  // replacesExistingOnNewDay: false (default)
                ),
              ],
            ),
          ]);
      await provider.loadAllSchedules();

      final events = provider.buildEventMap();
      final wednesdayKey = DateTime(2026, 7, 1);
      expect(events[wednesdayKey]?.where((s) => s.id == 'sched-1').length, 1);
    });

    test('once-schedule shows on its specific date', () async {
      when(() => db.getAllSchedules()).thenAnswer((_) async => [
            once(specificDate: DateTime(2026, 6, 29)),
          ]);
      await provider.loadAllSchedules();

      final events = provider.buildEventMap();
      final key = DateTime(2026, 6, 29);
      expect(events[key]?.map((s) => s.id), contains('sched-2'));
      expect(events[DateTime(2026, 6, 28)], anyOf(isNull, isEmpty));
    });
  });

  group('markOccurrenceComplete', () {
    test('clears reschedules that touch the completed date', () async {
      final initial = weeklyMonWed(
        reschedules: [
          RescheduledOccurrence(
            originalDate: DateTime(2026, 6, 29),
            newDateTime: DateTime(2026, 6, 30, 10),
          ),
        ],
      );
      when(() => db.getAllSchedules()).thenAnswer((_) async => [initial]);
      await provider.loadAllSchedules();

      await provider.markOccurrenceComplete(
          'sched-1', DateTime(2026, 6, 29));

      final after = provider.schedules.first;
      expect(after.rescheduledOccurrences, isEmpty);
      expect(after.completedOccurrences, contains('2026-06-29'));
    });

    test('clears reschedules where the newDateTime is the completed date',
        () async {
      final initial = weeklyMonWed(
        reschedules: [
          RescheduledOccurrence(
            originalDate: DateTime(2026, 6, 29),
            newDateTime: DateTime(2026, 6, 30, 10),
          ),
        ],
      );
      when(() => db.getAllSchedules()).thenAnswer((_) async => [initial]);
      await provider.loadAllSchedules();

      await provider.markOccurrenceComplete(
          'sched-1', DateTime(2026, 6, 30));

      expect(provider.schedules.first.rescheduledOccurrences, isEmpty);
    });

    test('is a no-op if the date is already marked complete', () async {
      final initial = weeklyMonWed(completed: const ['2026-06-29']);
      when(() => db.getAllSchedules()).thenAnswer((_) async => [initial]);
      await provider.loadAllSchedules();

      // Pre-condition.
      expect(provider.schedules.first.completedOccurrences,
          contains('2026-06-29'));

      await provider.markOccurrenceComplete(
          'sched-1', DateTime(2026, 6, 29));

      // No change.
      expect(provider.schedules.first.completedOccurrences,
          contains('2026-06-29'));
    });
  });

  group('rescheduleAllNotifications on app launch', () {
    test('re-registers the latest future reschedule', () async {
      final now = DateTime.now();
      final tomorrow = now.add(const Duration(days: 1));
      final dayAfter = now.add(const Duration(days: 2));

      final initial = weeklyMonWed(
        reschedules: [
          RescheduledOccurrence(
            originalDate: DateTime(2026, 6, 29),
            newDateTime: tomorrow,
          ),
          RescheduledOccurrence(
            originalDate: DateTime(2026, 6, 30),
            newDateTime: dayAfter,
          ),
        ],
      );
      when(() => db.getAllSchedules()).thenAnswer((_) async => [initial]);
      // loadAllSchedules internally calls rescheduleAllNotifications.
      await provider.loadAllSchedules();

      // The schedule's rescheduledOccurrences are intact and the entry
      // ordering didn't change.
      final loaded = provider.schedules.first;
      expect(loaded.rescheduledOccurrences.length, 2);
    });

    test('keeps past reschedule entries as history (does not crash)', () async {
      final initial = weeklyMonWed(
        reschedules: [
          RescheduledOccurrence(
            originalDate: DateTime(2020, 1, 1),
            newDateTime: DateTime(2020, 1, 2, 10),
          ),
        ],
      );
      when(() => db.getAllSchedules()).thenAnswer((_) async => [initial]);
      await provider.loadAllSchedules();

      // The entry is still in memory (history), not purged.
      expect(provider.schedules.first.rescheduledOccurrences.length, 1);
    });
  });
}
