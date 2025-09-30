import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hema_scoring_machine/widgets/active_timer_board.dart';
import 'package:hema_scoring_machine/widgets/reset_button.dart';

import '../widgets/big_button.dart';
import '../widgets/score_board.dart';
import '../widgets/timer_display.dart';
import '../widgets/time_control.dart';
import '../widgets/penalties_control.dart';
import '../utils/time_utils.dart';
import '../modules/fight_log/fight_log.dart';
import '../modules/fight_log/fight_log_view.dart';
import '../widgets/log_handle_panel.dart';

class ScorePage extends StatefulWidget {
  const ScorePage({super.key});

  @override
  State<ScorePage> createState() => _ScorePageState();
}

class _ScorePageState extends State<ScorePage> {
  final fightLog = FightLog();

  int leftScore = 0;
  int rightScore = 0;
  int leftWarning = 0;
  int rightWarning = 0;
  int leftCaution = 0;
  int rightCaution = 0;
  int doubleHits = 0;

  String leftName = "F1";
  String rightName = "F2";

  Duration timer = const Duration(minutes: 1, seconds: 30);
  Timer? countdown;
  bool running = false;

  void _inc(int Function() getter, void Function(int) setter) {
    setState(() => setter(getter() + 1));
  }

  void _dec(int Function() getter, void Function(int) setter) {
    setState(() {
      final value = getter();
      if (value > 0) setter(value - 1);
    });
  }

  void _onStartPressed() {
    setState(() {
      fightLog.startFight(); // or resume fight if needed
      fightLog.logDiff(
        leftScore: leftScore,
        rightScore: rightScore,
        leftWarning: leftWarning,
        rightWarning: rightWarning,
        leftCaution: leftCaution,
        rightCaution: rightCaution,
        doubleHits: doubleHits,
        leftName: leftName,
        rightName: rightName,
      );
    });
  }

  void startTimer() {
    _onStartPressed();
    countdown?.cancel();
    countdown = Timer.periodic(const Duration(milliseconds: 100), (t) {
      setState(() {
        if (timer.inMilliseconds > 0) {
          timer -= const Duration(milliseconds: 100);
          if (timer.isNegative) {
            timer = Duration.zero;
          }
        } else {
          t.cancel();
          running = false;
        }
      });
    });
    setState(() => running = true);
  }

  void stopTimer() {
    countdown?.cancel();
    setState(() => running = false);
  }

  void resetAll() {
    fightLog.reset();
    setState(() {
      leftScore = 0;
      rightScore = 0;
      leftWarning = 0;
      rightWarning = 0;
      leftCaution = 0;
      rightCaution = 0;
      doubleHits = 0;
      timer = const Duration(minutes: 1, seconds: 30);
    });
  }

  void resetTime() {
    setState(() {
      timer = const Duration(minutes: 1, seconds: 30);
    });
  }

  void swapFighters() {
    setState(() {
      // swap scores
      final tmpScore = leftScore;
      leftScore = rightScore;
      rightScore = tmpScore;

      // swap warnings
      final tmpWarning = leftWarning;
      leftWarning = rightWarning;
      rightWarning = tmpWarning;

      // swap cautions
      final tmpCaution = leftCaution;
      leftCaution = rightCaution;
      rightCaution = tmpCaution;

      // swap names
      final tmpName = leftName;
      leftName = rightName;
      rightName = tmpName;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (running) {
      return GestureDetector(
        onTap: stopTimer,
        child: Scaffold(
          backgroundColor: Colors.black,
          body: SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Center section
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TimerDisplay(
                          color: Colors.white,
                          time: formatTime(timer),
                          fontSize: 80,
                        ),
                        ActiveTimerBoard(
                          leftScore: leftScore,
                          rightScore: rightScore,
                        ),
                      ],
                    ),
                  ),
                ),

                // Bottom button section
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: SizedBox(
                    child: BigButton(
                      label: "Stop",
                      color: Colors.red,
                      fontSize: 28,
                      onPressed: stopTimer,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.only(top: 12, left: 12, right: 12, bottom: 8),
        child: Column(
          children: [
            /// Timer display
            TimerDisplay(
              time: formatTime(timer),
              fontSize: 70,
              onDoubleTap: () async {
                final newTime = await showTimeSelectDialog(context);

                if (newTime != null) {
                  setState(() {
                    timer = newTime;
                  });
                }
              },
            ),

            /// Time control
            TimeControl(
              onMinus1: () => setState(() {
                if (timer > const Duration(seconds: 1)) {
                  timer -= const Duration(seconds: 1);
                } else {
                  timer = Duration.zero;
                }
              }),
              onPlus3: () =>
                  setState(() => timer += const Duration(seconds: 3)),
              onPlus5: () =>
                  setState(() => timer += const Duration(seconds: 5)),
            ),

            /// Scoreboard with swap fighters icon
            ScoreBoard(
              leftName: leftName,
              rightName: rightName,
              leftScore: leftScore,
              rightScore: rightScore,
              onLeftTap: () => setState(() => leftScore++),
              onLeftLongPress: () => setState(() {
                if (leftScore > 0) leftScore--;
              }),
              onRightTap: () => setState(() => rightScore++),
              onRightLongPress: () => setState(() {
                if (rightScore > 0) rightScore--;
              }),
              swapFighters: swapFighters,
            ),

            SizedBox(
              width: double.infinity,
              height: 100,
              child: BigButton(
                label: "START",
                color: Colors.deepPurple,
                fontSize: 40,
                onPressed: startTimer,
              ),
            ),
            GestureDetector(
              onVerticalDragUpdate: (details) {
                // user dragged up
                if (details.primaryDelta != null &&
                    details.primaryDelta! < -10) {
                  FightLogView.show(context, fightLog);
                }
              },
              child: LogHandlePanel(fightLog: fightLog),
            ),

            const SizedBox(height: 16),

            /// Warnings + Doublehits
            PenaltiesControl(
              leftWarning: leftWarning,
              rightWarning: rightWarning,
              leftCaution: leftCaution,
              rightCaution: rightCaution,
              doubleHits: doubleHits,
              onLeftWarningPlus: () =>
                  _inc(() => leftWarning, (v) => leftWarning = v),
              onLeftWarningMinus: () =>
                  _dec(() => leftWarning, (v) => leftWarning = v),
              onRightWarningPlus: () =>
                  _inc(() => rightWarning, (v) => rightWarning = v),
              onRightWarningMinus: () =>
                  _dec(() => rightWarning, (v) => rightWarning = v),
              onDoublePlus: () => _inc(() => doubleHits, (v) => doubleHits = v),
              onDoubleMinus: () =>
                  _dec(() => doubleHits, (v) => doubleHits = v),
              onLeftCautionPlus: () =>
                  _inc(() => leftCaution, (v) => leftCaution = v),
              onLeftCautionMinus: () =>
                  _dec(() => leftCaution, (v) => leftCaution = v),
              onRightCautionPlus: () =>
                  _inc(() => rightCaution, (v) => rightCaution = v),
              onRightCautionMinus: () =>
                  _dec(() => rightCaution, (v) => rightCaution = v),
            ),
            const Spacer(),

            Row(
              children: [
                Expanded(
                  child: ResetButton(
                    label: "Reset",
                    color: Colors.red,
                    onPressed: resetAll,
                    onLongPress: resetTime,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
