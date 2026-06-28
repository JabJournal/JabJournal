import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jab_journal/models/schedule.dart';
import 'package:jab_journal/providers/schedule_provider.dart';
import 'package:jab_journal/screens/schedules/reschedule_dose_screen.dart';
import 'package:jab_journal/services/database/database_helper.dart';
import 'package:jab_journal/services/notification_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

class _MockDatabaseHelper extends Mock implements DatabaseHelper {}

class _MockNotificationService extends Mock implements NotificationService {}

class _RescheduleCall {
  _RescheduleCall({
    required this.scheduleId,
    required this.originalDate,
    required this.newDateTime,
    required this.replacesExistingOnNewDay,
  });
  final String scheduleId;
  final DateTime originalDate;
  final DateTime newDateTime;
  final bool replacesExistingOnNewDay;
}

/// Wraps a real [ScheduleProvider] and captures calls to
/// [rescheduleOccurrence] so widget tests can assert on the arguments
/// without coupling to mocktail's verify state machine. Reads (e.g. `schedules`)
/// are forwarded to the wrapped provider so the screen can see the same
/// loaded state.
class _SpyingProvider extends ScheduleProvider {
  _SpyingProvider(this._real) : super();

  final ScheduleProvider _real;
  final List<_RescheduleCall> calls = [];

  @override
  List<PeptideSchedule> get schedules => _real.schedules;

  @override
  Future<void> rescheduleOccurrence({
    required String scheduleId,
    required DateTime originalDate,
    required DateTime newDateTime,
    bool replacesExistingOnNewDay = false,
  }) async {
    calls.add(_RescheduleCall(
      scheduleId: scheduleId,
      originalDate: originalDate,
      newDateTime: newDateTime,
      replacesExistingOnNewDay: replacesExistingOnNewDay,
    ));
  }
}

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
    db = _MockDatabaseHelper();
    notifications = _MockNotificationService();
    when(() => db.getAllPeptides()).thenAnswer((_) async => []);
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

    provider = ScheduleProvider(
      databaseHelper: db,
      notificationService: notifications,
    );
  });

  RescheduleDoseScreen buildScreen({DateTime? originalDate}) {
    return RescheduleDoseScreen(
      scheduleId: 'sched-1',
      peptideId: 'pep-1',
      peptideName: 'BPC-157',
      dayOfWeek: 1, // Monday
      originalDate: originalDate ?? DateTime(2026, 6, 29),
    );
  }

  Widget wrap(Widget child, {ScheduleProvider? override}) {
    return ChangeNotifierProvider<ScheduleProvider>.value(
      value: override ?? provider,
      child: MaterialApp(home: child),
    );
  }

  group('rendering', () {
    testWidgets('shows the peptide name and explanatory copy', (tester) async {
      await tester.pumpWidget(wrap(buildScreen()));
      await tester.pumpAndSettle();

      expect(find.text('BPC-157'), findsOneWidget);
      expect(
        find.textContaining('Only this dose will be moved'),
        findsOneWidget,
      );
    });

    testWidgets('Save button is labelled "Save new time"', (tester) async {
      await tester.pumpWidget(wrap(buildScreen()));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(FilledButton, 'Save new time'), findsOneWidget);
    });
  });

  group('save — happy path (no conflict)', () {
    testWidgets(
        'calls rescheduleOccurrence with the picked date/time and originalDate',
        (tester) async {
      // Seed the provider with a once-schedule so the pop-up never appears.
      when(() => db.getAllSchedules()).thenAnswer((_) async => [
            PeptideSchedule(
              id: 'sched-1',
              peptideId: 'pep-1',
              frequency: ScheduleFrequency.once,
              timeOfDay: 10 * 3600,
              specificDate: DateTime(2026, 6, 29),
            ),
          ]);
      await provider.loadAllSchedules();

      final spy = _SpyingProvider(provider);
      await tester.pumpWidget(wrap(buildScreen(), override: spy));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Save new time'));
      await tester.pumpAndSettle();

      expect(spy.calls, hasLength(1));
      final call = spy.calls.single;
      expect(call.scheduleId, 'sched-1');
      expect(call.originalDate, DateTime(2026, 6, 29));
      // The default pick is "tomorrow at the same time" so the newDateTime
      // is in the future.
      expect(call.newDateTime.isAfter(DateTime.now()), isTrue);
      // Once-schedule → no conflict → replacesExistingOnNewDay is false.
      expect(call.replacesExistingOnNewDay, isFalse);
    });
  });

  group('conflict pop-up', () {
    testWidgets(
        'shows the pop-up when the new day is also a normal schedule day',
        (tester) async {
      // Weekly schedule that includes tomorrow's weekday. The screen's
      // default pick is tomorrow → conflict.
      final tomorrow = DateTime.now().add(const Duration(days: 1));
      when(() => db.getAllSchedules()).thenAnswer((_) async => [
            PeptideSchedule(
              id: 'sched-1',
              peptideId: 'pep-1',
              frequency: ScheduleFrequency.weekly,
              daysOfWeek: [tomorrow.weekday],
              timeOfDay: 10 * 3600,
            ),
          ]);
      await provider.loadAllSchedules();

      await tester.pumpWidget(wrap(buildScreen()));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Save new time'));
      await tester.pumpAndSettle();

      expect(find.text('Another dose is already scheduled'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Cancel'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Keep both'), findsOneWidget);
      expect(
        find.widgetWithText(FilledButton, 'Replace only this dose'),
        findsOneWidget,
      );
    });

    testWidgets('does not show the pop-up for a once-schedule', (tester) async {
      when(() => db.getAllSchedules()).thenAnswer((_) async => [
            PeptideSchedule(
              id: 'sched-1',
              peptideId: 'pep-1',
              frequency: ScheduleFrequency.once,
              timeOfDay: 10 * 3600,
              specificDate: DateTime(2026, 6, 29),
            ),
          ]);
      await provider.loadAllSchedules();

      await tester.pumpWidget(wrap(buildScreen()));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Save new time'));
      await tester.pumpAndSettle();

      expect(find.text('Another dose is already scheduled'), findsNothing);
      // The screen should have popped (no conflict to confirm).
      expect(find.byType(RescheduleDoseScreen), findsNothing);
    });

    testWidgets(
        '"Keep both" calls rescheduleOccurrence with replacesExistingOnNewDay=false',
        (tester) async {
      final tomorrow = DateTime.now().add(const Duration(days: 1));
      when(() => db.getAllSchedules()).thenAnswer((_) async => [
            PeptideSchedule(
              id: 'sched-1',
              peptideId: 'pep-1',
              frequency: ScheduleFrequency.weekly,
              daysOfWeek: [tomorrow.weekday],
              timeOfDay: 10 * 3600,
            ),
          ]);
      await provider.loadAllSchedules();

      final spy = _SpyingProvider(provider);
      await tester.pumpWidget(wrap(buildScreen(), override: spy));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Save new time'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Keep both'));
      await tester.pumpAndSettle();

      expect(spy.calls, hasLength(1));
      expect(spy.calls.single.replacesExistingOnNewDay, isFalse);
    });

    testWidgets(
        '"Replace" calls rescheduleOccurrence with replacesExistingOnNewDay=true',
        (tester) async {
      final tomorrow = DateTime.now().add(const Duration(days: 1));
      when(() => db.getAllSchedules()).thenAnswer((_) async => [
            PeptideSchedule(
              id: 'sched-1',
              peptideId: 'pep-1',
              frequency: ScheduleFrequency.weekly,
              daysOfWeek: [tomorrow.weekday],
              timeOfDay: 10 * 3600,
            ),
          ]);
      await provider.loadAllSchedules();

      final spy = _SpyingProvider(provider);
      await tester.pumpWidget(wrap(buildScreen(), override: spy));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Save new time'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(FilledButton, 'Replace only this dose'),
      );
      await tester.pumpAndSettle();

      expect(spy.calls, hasLength(1));
      expect(spy.calls.single.replacesExistingOnNewDay, isTrue);
    });

    testWidgets('"Cancel" closes the pop-up without rescheduling',
        (tester) async {
      final tomorrow = DateTime.now().add(const Duration(days: 1));
      when(() => db.getAllSchedules()).thenAnswer((_) async => [
            PeptideSchedule(
              id: 'sched-1',
              peptideId: 'pep-1',
              frequency: ScheduleFrequency.weekly,
              daysOfWeek: [tomorrow.weekday],
              timeOfDay: 10 * 3600,
            ),
          ]);
      await provider.loadAllSchedules();

      final spy = _SpyingProvider(provider);
      await tester.pumpWidget(wrap(buildScreen(), override: spy));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Save new time'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();

      expect(spy.calls, isEmpty);
      // The pop-up is gone but the screen is still mounted.
      expect(find.byType(RescheduleDoseScreen), findsOneWidget);
      expect(find.text('Another dose is already scheduled'), findsNothing);
    });
  });
}
