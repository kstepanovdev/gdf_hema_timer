import 'package:gdf_hema_timer/pages/mode_selection_page.dart';
import 'package:gdf_hema_timer/pages/opossum_setup_page.dart';
import 'package:gdf_hema_timer/modules/opossum/pending_submission.dart';
import 'support/opossum_fixture.dart';
import 'dart:io';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gdf_hema_timer/main.dart';
import 'package:gdf_hema_timer/l10n/gen/app_localizations.dart';
import 'package:gdf_hema_timer/modules/bout_session/bout_feedback.dart';
import 'package:gdf_hema_timer/modules/bout_session/bout_session.dart';
import 'package:gdf_hema_timer/modules/bout_session/bout_session_controller.dart';
import 'package:gdf_hema_timer/modules/fight_log/fight_event.dart';
import 'package:gdf_hema_timer/modules/settings/settings_storage.dart';
import 'package:gdf_hema_timer/modules/timer/storage.dart';
import 'package:gdf_hema_timer/pages/score_page.dart';
import 'package:gdf_hema_timer/utils/touch_number.dart';
import 'package:gdf_hema_timer/widgets/penalties_control.dart';
import 'package:gdf_hema_timer/widgets/score_board.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TestFeedback implements BoutFeedback {
  int hits = 0;
  int expirations = 0;
  bool disposed = false;
  @override
  Future<void> prepare() async {}
  @override
  Future<void> mutualHit() async {
    hits++;
  }

  @override
  Future<void> timeExpired() async {
    expirations++;
  }

  @override
  Future<void> dispose() async {
    disposed = true;
  }
}

Widget timerApp({
  BoutSessionController? controller,
  TestFeedback? feedback,
  String locale = 'en',
}) => MaterialApp(
  locale: Locale(locale),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: ScorePage(controller: controller, feedback: feedback ?? TestFeedback()),
);

Finder score(int index) => find
    .descendant(of: find.byType(ScoreBoard), matching: find.byType(TouchNumber))
    .at(index);
Finder penalty(int index) => find
    .descendant(
      of: find.byType(PenaltiesControl),
      matching: find.byType(TouchNumber),
    )
    .at(index);

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({'show_help_on_launch': false});
    FlutterSecureStorage.setMockInitialValues({});
    localeOverride.value = null;
    darkThemeEnabled.value = false;
    yehorsSpecialEnabled.value = false;
  });

  testWidgets('standalone opens with no server, credentials or working network', (
    tester,
  ) async {
    // Flutter tests reject all real HTTP; no integration configuration is provided.
    await HttpOverrides.runZoned(() async {
      await tester.pumpWidget(const ScoreApp());
      await tester.pumpAndSettle();
      expect(find.text('Standalone Timer'), findsOneWidget);
      await tester.tap(find.byKey(const Key('standalone-mode')));
      await tester.pumpAndSettle();
      expect(find.byType(ScoreBoard), findsOneWidget);
      expect(find.text('01:30.00'), findsOneWidget);
      expect(find.textContaining('Previous scores'), findsOneWidget);
      await tester.ensureVisible(score(0));
      await tester.tap(score(0));
      await tester.pump();
      expect(tester.widget<ScoreBoard>(find.byType(ScoreBoard)).leftScore, 1);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    }, createHttpClient: (_) => throw StateError('No network allowed'));
  });

  testWidgets('tournament entry opens setup without opening a bout', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ModeSelectionPage(
          opossumSetupBuilder: (_) => OpossumSetupPage(
            repository: MemoryPendingSubmissionRepository(),
            storage: FakeConnectionStorage(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('opossum-mode')));
    await tester.pumpAndSettle();
    expect(find.text('Opossum Tournament'), findsOneWidget);
    expect(find.byKey(const Key('opossum-url')), findsOneWidget);
    expect(find.byKey(const Key('opossum-token')), findsOneWidget);
    expect(find.byType(ScoreBoard), findsNothing);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('standalone-mode')), findsOneWidget);
  });

  testWidgets(
    'tap/hold corrections, swapping, penalties, mutual hits and log',
    (tester) async {
      final controller = BoutSessionController();
      final feedback = TestFeedback();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        timerApp(controller: controller, feedback: feedback),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(score(0));
      await tester.tap(score(0));
      await tester.pump();
      await tester.tap(score(0));
      await tester.pump();
      await tester.longPress(score(0));
      await tester.pump();
      expect(controller.session.a.score, 1);
      await tester.ensureVisible(find.byKey(const Key('swap-sides')));
      await tester.tap(find.byKey(const Key('swap-sides')));
      await tester.pump();
      await tester.ensureVisible(score(0));
      await tester.tap(score(0));
      await tester.pump();
      expect(controller.session.b.score, 1);
      expect(controller.session.a.score, 1);
      await tester.ensureVisible(penalty(0));
      await tester.tap(penalty(0));
      await tester.pump();
      expect(controller.session.b.warning, 1);
      await tester.tap(penalty(1));
      await tester.pump();
      expect(controller.session.b.caution, 1);
      await tester.ensureVisible(penalty(2));
      await tester.tap(penalty(2));
      await tester.pump();
      await tester.longPress(penalty(2));
      await tester.pump();
      expect(controller.session.mutualHits, 0);
      expect(feedback.hits, 1);
      expect(
        controller.fightLog.events.whereType<DoubleHitChanged>(),
        hasLength(2),
      );
      await tester.ensureVisible(find.text('Drag up for logs'));
      await tester.tap(find.text('Drag up for logs'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Double hit -1 (0)'), findsOneWidget);
      expect(find.textContaining('Display sides swapped'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      expect(feedback.disposed, isTrue);
    },
  );

  testWidgets('refresh lag does not slow the clock; expiry effect fires once', (
    tester,
  ) async {
    var elapsed = Duration.zero;
    final controller = BoutSessionController(
      duration: const Duration(seconds: 5),
      elapsed: () => elapsed,
    );
    final feedback = TestFeedback();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      timerApp(controller: controller, feedback: feedback),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('START'));
    await tester.tap(find.text('START'));
    await tester.pump();
    elapsed = const Duration(milliseconds: 2450);
    await tester.pump(const Duration(milliseconds: 16));
    expect(find.text('00:02.55'), findsOneWidget);
    await tester.tap(find.text('Stop'));
    await tester.pump();
    elapsed = const Duration(minutes: 1);
    expect(controller.remaining, const Duration(milliseconds: 2550));
    await tester.ensureVisible(find.text('START'));
    await tester.tap(find.text('START'));
    await tester.pump();
    elapsed += const Duration(seconds: 3);
    await tester.pump(const Duration(milliseconds: 16));
    expect(controller.running, isFalse);
    expect(feedback.expirations, 1);
    await tester.pump(const Duration(seconds: 1));
    expect(feedback.expirations, 1);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('background transition pauses and visibly requires time review', (
    tester,
  ) async {
    var elapsed = Duration.zero;
    final controller = BoutSessionController(elapsed: () => elapsed);
    addTearDown(controller.dispose);
    await tester.pumpWidget(timerApp(controller: controller));
    await tester.pumpAndSettle();
    controller.start();
    await tester.pump();
    elapsed = const Duration(seconds: 4);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    elapsed = const Duration(hours: 1);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(find.byKey(const Key('clock-interrupted')), findsOneWidget);
    expect(controller.running, isFalse);
    expect(controller.remaining, const Duration(seconds: 86));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'duration survives reopening, scores and session history do not leak',
    (tester) async {
      await saveTimerValue(const Duration(minutes: 2));
      await tester.pumpWidget(timerApp());
      await tester.pumpAndSettle();
      expect(find.text('02:00.00'), findsOneWidget);
      await tester.ensureVisible(score(0));
      await tester.tap(score(0));
      await tester.pump();
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(timerApp());
      await tester.pumpAndSettle();
      expect(tester.widget<ScoreBoard>(find.byType(ScoreBoard)).leftScore, 0);
      expect(find.text('02:00.00'), findsOneWidget);
      expect(find.textContaining('Previous scores'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'Ukrainian entry, controls and interruption messages fit a phone',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      localeOverride.value = const Locale('uk');
      await tester.pumpWidget(const ScoreApp());
      await tester.pumpAndSettle();
      expect(find.text('Автономний таймер'), findsOneWidget);
      await tester.tap(find.byKey(const Key('standalone-mode')));
      await tester.pumpAndSettle();
      expect(find.text('Зауваження'), findsNWidgets(2));
      expect(find.text('Попередження'), findsNWidgets(2));
      expect(find.text('Обопільні'), findsOneWidget);
      expect(find.byTooltip('Поміняти сторони учасників'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );
  testWidgets('reset gestures and time selection retain the saved duration', (
    tester,
  ) async {
    await saveTimerValue(const Duration(minutes: 2));
    final controller = BoutSessionController(
      duration: const Duration(seconds: 42),
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(timerApp(controller: controller));
    await tester.pumpAndSettle();
    controller.setScore(DisplaySide.left, 7);
    controller.setMutualHits(3);
    await tester.pump();
    await tester.ensureVisible(find.text('Reset'));
    await tester.longPress(find.text('Reset'));
    await tester.pump();
    expect(controller.remaining, const Duration(seconds: 42));
    expect(controller.session.a.score, 0);
    expect(controller.session.mutualHits, 0);
    controller.setScore(DisplaySide.right, 4);
    await tester.pump();
    await tester.tap(find.text('Reset'));
    await tester.pumpAndSettle();
    expect(controller.remaining, const Duration(minutes: 2));
    expect(controller.session.b.score, 0);
    await tester.longPress(find.text('02:00.00'));
    await tester.pumpAndSettle();
    expect(find.text('Select Time'), findsOneWidget);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(controller.remaining, const Duration(seconds: 90));
    expect(await loadTimerValue(), const Duration(seconds: 90));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('leaving requires review; cancel preserves the current bout', (
    tester,
  ) async {
    await tester.pumpWidget(const ScoreApp());
    await tester.tap(find.byKey(const Key('standalone-mode')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(score(0));
    await tester.tap(score(0));
    await tester.pump();
    await tester.tap(find.byTooltip('Leave bout'));
    await tester.pumpAndSettle();
    expect(find.text('Leave this bout?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(tester.widget<ScoreBoard>(find.byType(ScoreBoard)).leftScore, 1);
    await tester.tap(find.byTooltip('Leave bout'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Leave bout'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('standalone-mode')), findsOneWidget);
    await tester.tap(find.byKey(const Key('standalone-mode')));
    await tester.pumpAndSettle();
    expect(tester.widget<ScoreBoard>(find.byType(ScoreBoard)).leftScore, 0);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });

  test(
    'existing theme, locale, sound and duration settings survive reload',
    () async {
      await setDarkTheme(true);
      await setLocale(const Locale('uk'));
      await setYehorsSpecial(true);
      await saveTimerValue(const Duration(minutes: 3));
      darkThemeEnabled.value = false;
      localeOverride.value = null;
      yehorsSpecialEnabled.value = false;
      await loadSettings();
      expect(darkThemeEnabled.value, isTrue);
      expect(localeOverride.value, const Locale('uk'));
      expect(yehorsSpecialEnabled.value, isTrue);
      expect(await loadTimerValue(), const Duration(minutes: 3));
    },
  );
}
