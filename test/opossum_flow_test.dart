import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gdf_hema_timer/l10n/gen/app_localizations.dart';
import 'package:gdf_hema_timer/modules/bout_session/bout_session_controller.dart';
import 'package:gdf_hema_timer/modules/opossum/api_client.dart';
import 'package:gdf_hema_timer/modules/opossum/models.dart';
import 'package:gdf_hema_timer/modules/opossum/pending_submission.dart';
import 'package:gdf_hema_timer/modules/opossum/submission_controller.dart';
import 'package:gdf_hema_timer/pages/mode_selection_page.dart';
import 'package:gdf_hema_timer/pages/opossum_result_page.dart';
import 'package:gdf_hema_timer/pages/opossum_setup_page.dart';
import 'package:gdf_hema_timer/pages/score_page.dart';
import 'package:gdf_hema_timer/widgets/score_board.dart';
import 'package:gdf_hema_timer/utils/touch_number.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'support/opossum_fixture.dart';

Widget app(Widget home) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  locale: const Locale('en'),
  home: home,
);
Finder score(int index) => find
    .descendant(of: find.byType(ScoreBoard), matching: find.byType(TouchNumber))
    .at(index);
void main() {
  setUp(
    () =>
        SharedPreferences.setMockInitialValues({'show_help_on_launch': false}),
  );
  Future<void> connect(
    WidgetTester tester, {
    required FakeTimerServer server,
    String token = syntheticToken,
    FakeConnectionStorage? storage,
  }) async {
    await tester.pumpWidget(
      app(
        ModeSelectionPage(
          opossumSetupBuilder: (_) => OpossumSetupPage(
            storage: storage ?? FakeConnectionStorage(),
            repository: MemoryPendingSubmissionRepository(),
            createClient: (config) => HttpOpossumClient(
              config,
              client: server.client(),
              readRetries: 0,
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('opossum-mode')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('opossum-url')),
      'https://example.test',
    );
    await tester.enterText(find.byKey(const Key('opossum-token')), token);
    await tester.tap(find.text('Test and save connection'));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'connect, select tournament/nomination/assignment, swap, confirm, then return standalone',
    (tester) async {
      tester.view.physicalSize = const Size(1000, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final server = FakeTimerServer();
      await connect(tester, server: server);
      expect(find.text('Connection verified'), findsOneWidget);
      await tester.tap(find.text('Synthetic Timer Open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Longsword').first);
      await tester.pumpAndSettle();
      expect(find.textContaining('Pools · Pool 1 · Piste 1'), findsOneWidget);
      await tester.ensureVisible(find.textContaining('№ 1 ·'));
      await tester.tap(find.textContaining('№ 1 ·'));
      await tester.pumpAndSettle();
      expect(find.byType(ScorePage), findsOneWidget);
      final a = object(server.current['fighter_a']),
          b = object(server.current['fighter_b']);
      expect(find.text(a['display_name'] as String), findsOneWidget);
      await tester.tap(find.text('START'));
      await tester.pump();
      expect(find.textContaining(a['display_name'] as String), findsOneWidget);
      await tester.tap(find.text('Stop'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(score(0));
      await tester.tap(score(0));
      await tester.pump();
      await tester.ensureVisible(find.byKey(const Key('swap-sides')));
      await tester.tap(find.byKey(const Key('swap-sides')));
      await tester.pump();
      await tester.ensureVisible(score(0));
      await tester.tap(score(0));
      await tester.pump();
      await tester.tap(score(0));
      await tester.pump();
      await tester.ensureVisible(find.text('Review result'));
      await tester.tap(find.text('Review result'));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byKey(const Key('review-score')),
          matching: find.text(a['display_name'] as String),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('review-score')),
          matching: find.text(b['display_name'] as String),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('review-score')),
          matching: find.text('1'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('review-score')),
          matching: find.text('2'),
        ),
        findsOneWidget,
      );
      expect(server.writes, isEmpty);
      await tester.tap(find.byKey(const Key('confirm-result')));
      await tester.pumpAndSettle();
      expect(find.text('Accepted by Opossum'), findsOneWidget);
      expect(server.current['score_a'], 1);
      expect(server.current['score_b'], 2);
      expect(server.mutations, 1);
      await tester.tap(find.text('Return to worklist'));
      await tester.pumpAndSettle();
      expect(find.byType(ScorePage), findsNothing);
      await tester.pageBack();
      await tester.pumpAndSettle(); // nominations
      await tester.pageBack();
      await tester.pumpAndSettle(); // connection
      await tester.pageBack();
      await tester.pumpAndSettle(); // modes
      await tester.tap(find.byKey(const Key('standalone-mode')));
      await tester.pumpAndSettle();
      expect(tester.widget<ScoreBoard>(find.byType(ScoreBoard)).leftScore, 0);
      expect(find.text('01:30.00'), findsOneWidget);
      expect(server.mutations, 1);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );
  testWidgets('bad token leaves an actionable error inside setup', (
    tester,
  ) async {
    await connect(tester, server: FakeTimerServer(), token: 'invalid-token');
    expect(
      find.text('The device token is invalid, expired or revoked.'),
      findsOneWidget,
    );
    expect(find.text('Connection verified'), findsNothing);
  });
  testWidgets(
    'server outage and secure-storage failure are separate inline errors',
    (tester) async {
      final server = FakeTimerServer()..failReads = true;
      await connect(tester, server: server);
      expect(
        find.text(
          'The server is unavailable. Check the address and connection.',
        ),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox());
      await connect(
        tester,
        server: FakeTimerServer(),
        storage: FakeConnectionStorage()..fail = true,
      );
      expect(
        find.textContaining('Secure credential storage is unavailable'),
        findsOneWidget,
      );
      expect(find.text('Connection verified'), findsNothing);
    },
  );
  testWidgets('confirmation double tap cannot send two results', (
    tester,
  ) async {
    final server = FakeTimerServer()..gate = Completer<void>();
    final api = HttpOpossumClient(
      ConnectionConfig('https://example.test', syntheticToken),
      client: server.client(),
    );
    final bout = TimerBout.fromJson(server.current);
    final controller = SubmissionController(
      api: api,
      repository: MemoryPendingSubmissionRepository(),
      origin: 'https://example.test',
      nomination: NominationRef.fromJson(
        object(array(object(server.data['discovery'])['nominations']).first),
      ),
      bout: bout,
      session: bout.toSession(),
      deviceId: deviceId,
    );
    addTearDown(api.close);
    addTearDown(controller.dispose);
    await tester.pumpWidget(app(OpossumResultPage(controller: controller)));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('confirm-result')));
    await tester.tap(find.byKey(const Key('confirm-result')));
    await tester.tap(find.byKey(const Key('confirm-result')));
    await tester.pump();
    expect(server.writes, hasLength(1));
    server.gate!.complete();
    await tester.pumpAndSettle();
    expect(find.text('Accepted by Opossum'), findsOneWidget);
    expect(server.mutations, 1);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'local mutual-hit edits explicitly block an ordinary submission',
    (tester) async {
      final server = FakeTimerServer();
      final bout = TimerBout.fromJson(server.current);
      final api = HttpOpossumClient(
        ConnectionConfig('https://example.test', syntheticToken),
        client: server.client(),
      );
      final session = BoutSessionController(initialSession: bout.toSession())
        ..setMutualHits(3);
      final controller = SubmissionController(
        api: api,
        repository: MemoryPendingSubmissionRepository(),
        origin: 'https://example.test',
        nomination: NominationRef.fromJson(
          object(array(object(server.data['discovery'])['nominations']).first),
        ),
        bout: bout,
        session: session.session,
        deviceId: deviceId,
      );
      addTearDown(api.close);
      addTearDown(session.dispose);
      addTearDown(controller.dispose);
      await tester.pumpWidget(app(OpossumResultPage(controller: controller)));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('This API cannot submit changes to mutual hits'),
        findsOneWidget,
      );
      final button = tester.widget<FilledButton>(
        find.byKey(const Key('confirm-result')),
      );
      expect(button.onPressed, isNull);
      expect(server.writes, isEmpty);
    },
  );
  testWidgets(
    'uncertain acceptance is labelled truthfully and retried with the same request',
    (tester) async {
      final server = FakeTimerServer()..loseFirstReceipt = true;
      final api = HttpOpossumClient(
        ConnectionConfig('https://example.test', syntheticToken),
        client: server.client(),
        timeout: const Duration(milliseconds: 30),
      );
      final bout = TimerBout.fromJson(server.current);
      final controller = SubmissionController(
        api: api,
        repository: MemoryPendingSubmissionRepository(),
        origin: 'https://example.test',
        nomination: NominationRef.fromJson(
          object(array(object(server.data['discovery'])['nominations']).first),
        ),
        bout: bout,
        session: bout.toSession(),
        deviceId: deviceId,
      );
      addTearDown(api.close);
      addTearDown(controller.dispose);
      await tester.pumpWidget(app(OpossumResultPage(controller: controller)));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('confirm-result')));
      await tester.tap(find.byKey(const Key('confirm-result')));
      await tester.pump(const Duration(milliseconds: 40));
      await tester.pumpAndSettle();
      expect(controller.state, SubmissionState.uncertain);
      expect(
        find.text('Acceptance unknown — retry the same request.'),
        findsOneWidget,
      );
      expect(find.text('Not submitted'), findsNothing);
      expect(server.mutations, 1);
      final firstId = controller.request!.idempotencyKey;
      await tester.ensureVisible(find.byKey(const Key('confirm-result')));
      await tester.tap(find.byKey(const Key('confirm-result')));
      await tester.pumpAndSettle();
      expect(
        find.text('Previously accepted — confirmed by idempotent replay'),
        findsOneWidget,
      );
      expect(controller.request!.idempotencyKey, firstId);
      expect(server.mutations, 1);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
