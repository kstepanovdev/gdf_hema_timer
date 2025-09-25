import 'dart:async';
import 'package:flutter/material.dart';

import '../widgets/big_button.dart';
import '../widgets/score_board.dart';
import '../widgets/timer_display.dart';
import '../widgets/time_control.dart';
import '../widgets/warn_and_double.dart';
import '../utils/time_utils.dart';

class ScorePage extends StatefulWidget {
  const ScorePage({super.key});

  @override
  State<ScorePage> createState() => _ScorePageState();
}

class _ScorePageState extends State<ScorePage> {
  int leftScore = 0;
  int rightScore = 0;
  int leftWarn = 0;
  int rightWarn = 0;
  int doubleHits = 0;

  String leftName = "Fighter 1";
  String rightName = "Fighter 2";

  Duration timer = const Duration(minutes: 1, seconds: 30);
  Timer? countdown;
  bool running = false;

  void startTimer() {
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

  void resetTimer() {
    stopTimer();
    setState(() => timer = const Duration(minutes: 1, seconds: 30));
  }

  void resetAll() {
    stopTimer();
    setState(() {
      leftScore = 0;
      rightScore = 0;
      leftWarn = 0;
      rightWarn = 0;
      doubleHits = 0;
      timer = const Duration(minutes: 1, seconds: 30);
    });
  }

  void swapFighters() {
    setState(() {
      final tempName = leftName;
      final tempScore = leftScore;
      final tempWarn = leftWarn;

      leftName = rightName;
      leftScore = rightScore;
      leftWarn = rightWarn;

      rightName = tempName;
      rightScore = tempScore;
      rightWarn = tempWarn;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (running) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: stopTimer,
        child: Scaffold(
          backgroundColor: Colors.black,
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TimerDisplay(time: formatTime(timer), color: Colors.white),
                const SizedBox(height: 20),
                BigButton(label: "Stop", color: Colors.red, onPressed: stopTimer),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            /// Scoreboard with swap fighters icon
            ScoreBoard(
              leftName: leftName,
              rightName: rightName,
              leftScore: leftScore,
              rightScore: rightScore,
              onLeftPlus: () => setState(() => leftScore++),
              onLeftMinus: () => setState(() {
                if (leftScore > 0) leftScore--;
              }),
              onRightPlus: () => setState(() => rightScore++),
              onRightMinus: () => setState(() {
                if (rightScore > 0) rightScore--;
              }),
              swapFighters: swapFighters, // 👈 pass small button action
            ),

            const SizedBox(height: 12),

            /// Timer display
            TimerDisplay(time: formatTime(timer)),

            const SizedBox(height: 12),

            /// Time control
            TimeControl(
              onMinus30: () => setState(() {
                if (timer > const Duration(seconds: 30)) {
                  timer -= const Duration(seconds: 30);
                } else {
                  timer = Duration.zero;
                }
              }),
              onPlus30: () => setState(() => timer += const Duration(seconds: 30)),
              onMinus1: () => setState(() {
                if (timer > const Duration(seconds: 1)) {
                  timer -= const Duration(seconds: 1);
                } else {
                  timer = Duration.zero;
                }
              }),
              onPlus1: () => setState(() => timer += const Duration(seconds: 1)),
            ),



            const SizedBox(height: 16),

            /// Start button (biggest)
            SizedBox(
              width: double.infinity,
              height: 100,
              child: BigButton(
                label: "START",
                color: Colors.deepPurple,
                onPressed: startTimer,
              ),
            ),

            const SizedBox(height: 16),

            /// Warnings + Doublehits
            WarnAndDouble(
              leftWarn: leftWarn,
              rightWarn: rightWarn,
              doubleHits: doubleHits,
              onLeftWarnPlus: () => setState(() => leftWarn++),
              onLeftWarnMinus: () => setState(() {
                if (leftWarn > 0) leftWarn--;
              }),
              onRightWarnPlus: () => setState(() => rightWarn++),
              onRightWarnMinus: () => setState(() {
                if (rightWarn > 0) rightWarn--;
              }),
              onDoublePlus: () => setState(() => doubleHits++),
              onDoubleMinus: () => setState(() {
                if (doubleHits > 0) doubleHits--;
              }),
            ),

            const SizedBox(height: 16),

            /// Reset all + Reset timer
            Row(
              children: [
                Expanded(child: BigButton(label: "Reset all", color: Colors.red, onPressed: resetAll)),
                const SizedBox(width: 8),
                Expanded(child: BigButton(label: "Reset timer", color: Colors.orange, onPressed: resetTimer)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
