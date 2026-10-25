import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gdf_hema_timer/l10n/gen/app_localizations.dart';
import 'package:gdf_hema_timer/modules/bout_session/bout_session_controller.dart';
import 'package:gdf_hema_timer/modules/bout_session/bout_session.dart';
import 'package:gdf_hema_timer/modules/opossum/api_client.dart';
import 'package:gdf_hema_timer/modules/opossum/judging.dart';
import 'package:gdf_hema_timer/modules/opossum/judging_controller.dart';
import 'package:gdf_hema_timer/modules/opossum/models.dart';
import 'package:gdf_hema_timer/modules/opossum/pending_submission.dart';
import 'package:gdf_hema_timer/modules/opossum/session_snapshot.dart';
import 'package:gdf_hema_timer/widgets/opossum_judging_panel.dart';
import 'support/judging_fixture.dart';
import 'support/opossum_fixture.dart';

/// UI-only harness: transport/durability are exercised by the SQLite tests.
class PanelController extends JudgingController {
  PanelController(
    OpossumClient api,
    BoutSessionController session,
    TimerBout bout,
  ) : super(
        api: api,
        session: session,
        initialBout: bout,
        origin: 'https://example.test',
        deviceId: '00000000-0000-4000-8000-000000000fff',
        snapshot: () => SessionSnapshot(
          origin: 'https://example.test',
          nomination: NominationRef.fromJson(
            object(array(object(fixture()['discovery'])['nominations']).first),
          ),
          bout: bout,
          session: session.session,
          remainingMs: 90000,
          configuredMs: 90000,
          wasRunning: false,
          events: [],
          savedAt: DateTime.now(),
        ),
      );
  PendingSubmission? captured;
  @override
  bool canIssue(JudgeEventKind kind, String? fighterId) =>
      state?.judgeWrite == true && !terminal;
  @override
  Future<void> confirm(
    JudgeEventKind kind, {
    String? fighterId,
    JudgingState? basis,
    SessionSnapshot? captured,
  }) async {
    this.captured = PendingSubmission.judge(
      origin: origin,
      judging: state!,
      session: session.session,
      kind: kind,
      fighterId: fighterId,
      deviceId: deviceId,
    );
    notifyListeners();
  }
}

void main() {
  late FakeJudgingServer server;
  late HttpOpossumClient api;
  late BoutSessionController session;
  late PanelController controller;
  setUp(() async {
    server = FakeJudgingServer('discipline');
    api = HttpOpossumClient(
      ConnectionConfig('https://example.test', syntheticToken),
      client: server.client(),
    );
    final initial = JudgingState.fromJson(server.judging);
    session = BoutSessionController(initialSession: initial.bout.toSession());
    controller = PanelController(api, session, initial.bout);
    await controller.start();
  });
  tearDown(() {
    controller.dispose();
    session.dispose();
    api.close();
  });
  Widget app([Locale locale = const Locale('uk')]) => MaterialApp(
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: SingleChildScrollView(
        child: OpossumJudgingPanel(controller: controller),
      ),
    ),
  );
  testWidgets(
    'Ukrainian controls explicitly confirm the correct fighter after a side swap',
    (tester) async {
      session.swapSides();
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      final left = session.at(DisplaySide.left);
      await tester.tap(find.byKey(const Key('judge-remark-left')));
      await tester.pumpAndSettle();
      expect(find.text('Підтвердити фактичну суддівську дію'), findsOneWidget);
      expect(find.text(left.name), findsNWidgets(2));
      await tester.tap(find.text('Скасувати'));
      await tester.pumpAndSettle();
      expect(controller.captured, isNull);
      await tester.tap(find.byKey(const Key('judge-warning-left')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('confirm-judge-event')));
      await tester.pumpAndSettle();
      expect(controller.captured!.judgeEvent, {
        'type': 'WARNING',
        'participant_id': left.id,
      });
      expect(
        controller.state!.fighter(left.id).warnings,
        0,
      ); // confirmation alone is never official
      expect(find.byKey(Key('official-sanctions-${left.id}')), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'read-only scope disables official controls and accepted records have organizer-only correction',
    (tester) async {
      final raw = clone(server.judging);
      object(raw['permissions'])['judge_write'] = false;
      controller.state = JudgingState.fromJson(raw);
      await tester.pumpWidget(app(const Locale('en')));
      await tester.pumpAndSettle();
      final button = tester.widget<FilledButton>(
        find.byKey(const Key('judge-warning-left')),
      );
      expect(button.onPressed, isNull);
      expect(
        find.textContaining('cannot issue judging events'),
        findsOneWidget,
      );
      await tester.ensureVisible(find.text('Official judging history'));
      await tester.tap(find.text('Official judging history'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('only be corrected at the organizer desk'),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'mobile shows the server Double Loss and never offers another hit',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      controller.state = JudgingState.fromJson(
        object(
          object(
            array(object(judgingFixture()['rr'])['operations']).last,
          )['judging'],
        ),
      );
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('official-double-loss')), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('judge-mutual-hit')))
            .onPressed,
        isNull,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
