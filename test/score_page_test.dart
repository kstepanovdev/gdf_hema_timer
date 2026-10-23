import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gdf_hema_timer/utils/touch_number.dart';
import 'package:gdf_hema_timer/widgets/fight_in_progress.dart';
import 'package:gdf_hema_timer/widgets/penalties_control.dart';
import 'package:gdf_hema_timer/widgets/score_board.dart';

import 'support/app_harness.dart';

Finder _numbersIn(Type parent) => find.descendant(
  of: find.byType(parent),
  matching: find.byType(TouchNumber),
);

final _leftScore = _numbersIn(ScoreBoard).at(0);
final _rightScore = _numbersIn(ScoreBoard).at(1);

/// In screen order: left warning, left caution, double, right warning,
/// right caution.
final _penalties = [
  for (var i = 0; i < 5; i++) _numbersIn(PenaltiesControl).at(i),
];
final _leftWarning = _penalties[0];
final _double = _penalties[2];

extension on WidgetTester {
  int valueOf(Finder number) => widget<TouchNumber>(number).value;

  Future<void> add(Finder number) async {
    await tap(number);
    await pump();
  }

  Future<void> remove(Finder number) async {
    await longPress(number);
    await pump();
  }

  /// Taps START and renders the first frame (the running clock never settles).
  Future<void> start() async {
    await tap(find.text('START'));
    await pump();
  }

  Future<void> tapText(String text) async {
    await tap(find.text(text));
    await pumpAndSettle();
  }
}

void main() {
  setUpAll(loadAppFonts);

  group('screen', () {
    testWidgets('stays on whenever the app is open, timer or not', (
      tester,
    ) async {
      final log = await pumpApp(tester);
      expect(log.wakelock, [true]);

      await tester.start();
      await tester.tapText('Stop');
      expect(log.wakelock, [true], reason: 'the timer leaves it alone');

      // Off to the background and back, as the OS reports it.
      for (final state in [
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
        AppLifecycleState.paused,
        AppLifecycleState.hidden,
        AppLifecycleState.inactive,
        AppLifecycleState.resumed,
      ]) {
        tester.binding.handleAppLifecycleStateChanged(state);
      }
      expect(log.wakelock, [true, true], reason: 're-requested on return');
    });
  });

  group('timer', () {
    testWidgets('START runs the clock; Stop ends it', (tester) async {
      await pumpApp(tester);

      await tester.start();
      expect(find.byType(ActiveTimerBoard), findsOneWidget);

      await tester.pump(const Duration(seconds: 1));
      expect(find.text('01:29.00'), findsOneWidget);

      await tester.tapText('Stop');
      expect(find.text('START'), findsOneWidget);
      expect(find.text('01:29.00'), findsOneWidget);
    });

    testWidgets('tapping anywhere on the running screen stops it', (
      tester,
    ) async {
      await pumpApp(tester);
      await tester.start();

      await tester.tap(find.byType(ActiveTimerBoard));
      await tester.pumpAndSettle();
      expect(find.text('START'), findsOneWidget);
    });

    testWidgets('reaching zero stops and vibrates', (tester) async {
      final log = await pumpApp(tester, prefs: {'timer_duration': 2});
      await tester.start();

      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(find.text('START'), findsOneWidget);
      expect(find.text('00:00.00'), findsOneWidget);
      expect(log.vibrations, [1000]);
    });

    testWidgets('time buttons nudge the clock', (tester) async {
      await pumpApp(tester);
      await tester.tapText('+3s');
      expect(find.text('01:33.00'), findsOneWidget);
      await tester.tapText('+5s');
      expect(find.text('01:38.00'), findsOneWidget);
      await tester.tapText('-1s');
      expect(find.text('01:37.00'), findsOneWidget);
    });

    testWidgets('-1s never goes below zero', (tester) async {
      await pumpApp(tester, prefs: {'timer_duration': 0});
      await tester.tapText('-1s');
      expect(find.text('00:00.00'), findsOneWidget);
    });

    testWidgets('choosing a round time saves it and starts a new bout', (
      tester,
    ) async {
      await pumpApp(tester);
      await tester.add(_leftScore);

      await tester.longPress(find.text('01:30.00'));
      await tester.pumpAndSettle();
      await tester.tapText('1 m');
      await tester.tap(find.text('2 m').last);
      await tester.pumpAndSettle();
      await tester.tapText('30 s');
      await tester.tap(find.text('0 s').last);
      await tester.pumpAndSettle();
      await tester.tapText('OK');

      expect(find.text('02:00.00'), findsOneWidget);
      expect(tester.valueOf(_leftScore), 0);
      expect(await savedPref('timer_duration'), 120);
    });
  });

  group('scoring', () {
    testWidgets('tap adds a point, hold removes one, never below zero', (
      tester,
    ) async {
      await pumpApp(tester);
      await tester.add(_leftScore);
      await tester.add(_leftScore);
      await tester.add(_rightScore);
      expect((tester.valueOf(_leftScore), tester.valueOf(_rightScore)), (2, 1));

      await tester.remove(_leftScore);
      await tester.remove(_rightScore);
      await tester.remove(_rightScore);
      expect((tester.valueOf(_leftScore), tester.valueOf(_rightScore)), (1, 0));
    });

    testWidgets('every penalty and double counter adds and removes', (
      tester,
    ) async {
      await pumpApp(tester);
      for (final counter in _penalties) {
        await tester.add(counter);
        await tester.add(counter);
        expect(tester.valueOf(counter), 2);
        await tester.remove(counter);
        await tester.remove(counter);
        await tester.remove(counter);
        expect(tester.valueOf(counter), 0);
      }
    });

    testWidgets('fight log lists scores and penalties but not corrections', (
      tester,
    ) async {
      await pumpApp(tester);
      await tester.start();
      await tester.tapText('Stop');
      await tester.add(_leftScore);
      await tester.remove(_leftScore);
      await tester.add(_leftWarning);
      await tester.remove(_leftWarning);
      await tester.add(_double);
      await tester.remove(_double);

      await tester.drag(find.text('Drag up for logs'), const Offset(0, -200));
      await tester.pumpAndSettle();

      final lines = find.descendant(
        of: find.byType(BottomSheet),
        matching: find.byType(Text),
      );
      expect(tester.widgetList<Text>(lines).map((t) => t.data), [
        '01:30.00 - Double hit',
        '01:30.00 - Warning to F1',
        '01:30.00 - 0 : 0',
        '01:30.00 - 1 : 0',
        '01:30.00 - Fight started',
      ]);
    });

    testWidgets("Yehor's special plays the sound only when adding a Double", (
      tester,
    ) async {
      final log = await pumpApp(tester, prefs: {'yehors_special': true});
      await tester.add(_double);
      await tester.remove(_double);
      expect(log.audio.where((m) => m == 'resume'), hasLength(1));
    });

    testWidgets("no sound when Yehor's special is off", (tester) async {
      final log = await pumpApp(tester);
      await tester.add(_double);
      expect(log.audio, contains('setSourceUrl'), reason: 'sound preloaded');
      expect(log.audio, isNot(contains('resume')));
    });
  });

  group('reset', () {
    Future<void> playABit(WidgetTester tester) async {
      await tester.add(_leftScore);
      for (final counter in _penalties) {
        await tester.add(counter);
      }
      await tester.tapText('+3s');
      expect(find.text('01:33.00'), findsOneWidget);
    }

    void expectClearBoard(WidgetTester tester) {
      for (final n in [_leftScore, _rightScore, ..._penalties]) {
        expect(tester.valueOf(n), 0);
      }
    }

    testWidgets('Reset clears the bout and restores the saved time', (
      tester,
    ) async {
      await pumpApp(tester);
      await playABit(tester);
      await tester.tapText('Reset');
      expectClearBoard(tester);
      expect(find.text('01:30.00'), findsOneWidget);
    });

    testWidgets('long-pressing Reset clears the bout but keeps the time', (
      tester,
    ) async {
      await pumpApp(tester);
      await playABit(tester);
      await tester.longPress(find.text('Reset'));
      await tester.pumpAndSettle();
      expectClearBoard(tester);
      expect(find.text('01:33.00'), findsOneWidget);
    });
  });

  group('settings', () {
    testWidgets('tutorial shows on first launch until dismissed for good', (
      tester,
    ) async {
      await pumpApp(tester, prefs: {'show_help_on_launch': true});
      expect(find.text('How to use'), findsOneWidget);

      await tester.tapText("Don't show this again");
      await tester.tapText('Continue');
      expect(find.text('How to use'), findsNothing);
      expect(await savedPref('show_help_on_launch'), false);
    });

    testWidgets('drawer toggles apply immediately and are saved', (
      tester,
    ) async {
      await pumpApp(tester);
      tester.firstState<ScaffoldState>(find.byType(Scaffold)).openDrawer();
      await tester.pumpAndSettle();

      await tester.tapText('Dark theme');
      expect(
        Theme.of(tester.element(find.text('START'))).brightness,
        Brightness.dark,
      );
      expect(await savedPref('dark_theme'), true);

      await tester.tapText("Yehor's special");
      expect(await savedPref('yehors_special'), true);

      await tester.tapText('System default');
      await tester.tap(find.text('Українська').last);
      await tester.pumpAndSettle();
      expect(find.text('СТАРТ'), findsOneWidget);
      expect(await savedPref('locale'), 'uk');
    });

    testWidgets('saved settings are applied on launch', (tester) async {
      await pumpApp(tester, prefs: {'dark_theme': true, 'locale': 'uk'});
      expect(find.text('СТАРТ'), findsOneWidget);
      expect(
        Theme.of(tester.element(find.text('СТАРТ'))).brightness,
        Brightness.dark,
      );
    });
  });
}
