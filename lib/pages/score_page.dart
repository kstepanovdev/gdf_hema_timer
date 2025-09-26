import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hema_scoring_machine/widgets/active_timer_board.dart';

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

  String leftName = "F1";
  String rightName = "F2";

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
      // swap scores
      final tmpScore = leftScore;
      leftScore = rightScore;
      rightScore = tmpScore;

      // swap warnings
      final tmpWarn = leftWarn;
      leftWarn = rightWarn;
      rightWarn = tmpWarn;

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
        behavior: HitTestBehavior.opaque,
        onTap: stopTimer,
        child: Scaffold(
          backgroundColor: Colors.black,
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ActiveTimerBoard(leftScore: leftScore, rightScore: rightScore),
                TimerDisplay(color: Colors.white, time: formatTime(timer)),

                const SizedBox(height: 20),
                BigButton(
                  label: "Stop",
                  color: Colors.red,
                  onPressed: stopTimer,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(top: 0, left: 12, right: 12, bottom: 8),
        child: Column(
          children: [
            /// Timer display
            TimerDisplay(
              time: formatTime(timer),
              onDoubleTap: () async {
                final newTime = await showDialog<Duration>(
                  context: context,
                  builder: (context) {
                    final minutesController = TextEditingController();
                    final secondsController = TextEditingController();
                    return AlertDialog(
                      title: const Text("Set Custom Time"),
                      content: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: minutesController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: "Minutes",
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: TextField(
                              controller: secondsController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: "Seconds",
                              ),
                            ),
                          ),
                        ],
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text("Cancel"),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            final min =
                                int.tryParse(minutesController.text) ?? 0;
                            final sec =
                                int.tryParse(secondsController.text) ?? 0;
                            Navigator.pop(
                              context,
                              Duration(minutes: min, seconds: sec),
                            );
                          },
                          child: const Text("Set"),
                        ),
                      ],
                    );
                  },
                );

                if (newTime != null) {
                  setState(() {
                    timer = newTime;
                  });
                }
              },
            ),

            const SizedBox(height: 12),

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

            const SizedBox(height: 12),

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

            const SizedBox(height: 4),

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
                Expanded(
                  child: BigButton(
                    label: "Reset all",
                    color: Colors.red,
                    onPressed: resetAll,
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
