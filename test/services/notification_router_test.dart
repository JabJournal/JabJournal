import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jab_journal/screens/doses/log_dose_screen.dart';
import 'package:jab_journal/screens/schedules/reschedule_dose_screen.dart';
import 'package:jab_journal/services/notification_router.dart';

void main() {
  // The router is a long-lived singleton. Reset its static state before every
  // test so we don't leak pending navigation between tests.
  setUp(NotificationRouter.resetForTesting);

  group('buildSchedulePayload', () {
    test('encodes the type, schedule, peptide, and dayOfWeek as JSON', () {
      final payload = NotificationRouter.buildSchedulePayload(
        scheduleId: 'sched-1',
        peptideId: 'pep-1',
        peptideName: 'BPC-157',
        dayOfWeek: 1,
      );
      expect(payload, contains('"type":"schedule"'));
      expect(payload, contains('"scheduleId":"sched-1"'));
      expect(payload, contains('"peptideId":"pep-1"'));
      expect(payload, contains('"peptideName":"BPC-157"'));
      expect(payload, contains('"dayOfWeek":1'));
    });
  });

  group('handleResponse', () {
    NotificationResponse responseFor({
      String? actionId,
      required String payload,
    }) {
      return NotificationResponse(
        notificationResponseType: NotificationResponseType.selectedNotification,
        actionId: actionId,
        payload: payload,
      );
    }

    String schedulePayload({int dayOfWeek = 1}) =>
        NotificationRouter.buildSchedulePayload(
          scheduleId: 'sched-1',
          peptideId: 'pep-1',
          peptideName: 'BPC-157',
          dayOfWeek: dayOfWeek,
        );

    Widget testApp() => MaterialApp(
          navigatorKey: NotificationRouter.navigatorKey,
          home: const Scaffold(body: Text('home')),
        );

    testWidgets('routes body tap to LogDoseScreen', (tester) async {
      await tester.pumpWidget(testApp());
      await tester.pumpAndSettle();

      NotificationRouter.handleResponse(
        responseFor(payload: schedulePayload()),
      );
      await tester.pumpAndSettle();

      expect(find.byType(LogDoseScreen), findsOneWidget);
      expect(find.byType(RescheduleDoseScreen), findsNothing);
    });

    testWidgets('routes log_dose action to LogDoseScreen', (tester) async {
      await tester.pumpWidget(testApp());
      await tester.pumpAndSettle();

      NotificationRouter.handleResponse(
        responseFor(
          actionId: NotificationRouter.logDoseActionId,
          payload: schedulePayload(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(LogDoseScreen), findsOneWidget);
    });

    testWidgets('routes reschedule_dose action to RescheduleDoseScreen',
        (tester) async {
      await tester.pumpWidget(testApp());
      await tester.pumpAndSettle();

      NotificationRouter.handleResponse(
        responseFor(
          actionId: NotificationRouter.rescheduleDoseActionId,
          payload: schedulePayload(dayOfWeek: 1),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(RescheduleDoseScreen), findsOneWidget);
      expect(find.byType(LogDoseScreen), findsNothing);
    });

    testWidgets('passes the payload fields through to the screen arguments',
        (tester) async {
      await tester.pumpWidget(testApp());
      await tester.pumpAndSettle();

      NotificationRouter.handleResponse(
        responseFor(
          actionId: NotificationRouter.rescheduleDoseActionId,
          payload: schedulePayload(dayOfWeek: 3),
        ),
      );
      await tester.pumpAndSettle();

      final reschedule = tester.widget<RescheduleDoseScreen>(
        find.byType(RescheduleDoseScreen),
      );
      expect(reschedule.scheduleId, 'sched-1');
      expect(reschedule.peptideId, 'pep-1');
      expect(reschedule.peptideName, 'BPC-157');
      expect(reschedule.dayOfWeek, 3);
      // originalDate defaults to today (date-only).
      final today = DateTime.now();
      expect(reschedule.originalDate.year, today.year);
      expect(reschedule.originalDate.month, today.month);
      expect(reschedule.originalDate.day, today.day);
    });

    testWidgets('ignores payloads with the wrong type', (tester) async {
      await tester.pumpWidget(testApp());
      await tester.pumpAndSettle();

      NotificationRouter.handleResponse(
        responseFor(payload: '{"type":"not_schedule"}'),
      );
      await tester.pumpAndSettle();

      expect(find.byType(LogDoseScreen), findsNothing);
      expect(find.byType(RescheduleDoseScreen), findsNothing);
    });

    testWidgets('ignores payloads missing required fields', (tester) async {
      await tester.pumpWidget(testApp());
      await tester.pumpAndSettle();

      // Missing peptideId
      NotificationRouter.handleResponse(
        responseFor(payload: '{"type":"schedule","peptideName":"X"}'),
      );
      await tester.pumpAndSettle();

      expect(find.byType(LogDoseScreen), findsNothing);
    });

    testWidgets('ignores payloads that fail to JSON-decode', (tester) async {
      await tester.pumpWidget(testApp());
      await tester.pumpAndSettle();

      NotificationRouter.handleResponse(
        responseFor(payload: 'not valid json'),
      );
      await tester.pumpAndSettle();

      expect(find.byType(LogDoseScreen), findsNothing);
    });

    testWidgets('ignores empty payloads', (tester) async {
      await tester.pumpWidget(testApp());
      await tester.pumpAndSettle();

      NotificationRouter.handleResponse(responseFor(payload: ''));
      await tester.pumpAndSettle();

      expect(find.byType(LogDoseScreen), findsNothing);
    });

    testWidgets('cold-start: reschedule action stores pending nav and replays it',
        (tester) async {
      // Pump WITHOUT a navigator mounted — handleResponse arrives before
      // the widget tree is ready.
      NotificationRouter.handleResponse(
        responseFor(
          actionId: NotificationRouter.rescheduleDoseActionId,
          payload: schedulePayload(dayOfWeek: 1),
        ),
      );

      // Now mount the tree and call flushPending.
      await tester.pumpWidget(testApp());
      await tester.pumpAndSettle();

      // Before flushPending, no screen is pushed.
      expect(find.byType(RescheduleDoseScreen), findsNothing);

      NotificationRouter.flushPending();
      await tester.pumpAndSettle();

      expect(find.byType(RescheduleDoseScreen), findsOneWidget);
    });

    testWidgets('cold-start: log_dose action also stores pending nav',
        (tester) async {
      NotificationRouter.handleResponse(
        responseFor(payload: schedulePayload()),
      );

      await tester.pumpWidget(testApp());
      await tester.pumpAndSettle();

      NotificationRouter.flushPending();
      await tester.pumpAndSettle();

      expect(find.byType(LogDoseScreen), findsOneWidget);
    });

    testWidgets('flushPending is a no-op when nothing is pending',
        (tester) async {
      await tester.pumpWidget(testApp());
      await tester.pumpAndSettle();

      NotificationRouter.flushPending();
      await tester.pumpAndSettle();

      // Still on the home screen.
      expect(find.byType(LogDoseScreen), findsNothing);
      expect(find.byType(RescheduleDoseScreen), findsNothing);
    });

    testWidgets('dedup: a second reschedule tap while one is open is dropped',
        (tester) async {
      await tester.pumpWidget(testApp());
      await tester.pumpAndSettle();

      NotificationRouter.handleResponse(
        responseFor(
          actionId: NotificationRouter.rescheduleDoseActionId,
          payload: schedulePayload(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(RescheduleDoseScreen), findsOneWidget);

      // Second tap — the dedup flag should swallow it.
      NotificationRouter.handleResponse(
        responseFor(
          actionId: NotificationRouter.rescheduleDoseActionId,
          payload: schedulePayload(),
        ),
      );
      await tester.pumpAndSettle();

      // Still only one RescheduleDoseScreen on the stack.
      expect(find.byType(RescheduleDoseScreen), findsOneWidget);
    });
  });
}
