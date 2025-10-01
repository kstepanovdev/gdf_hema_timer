import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hema_scoring_machine/modules/timer/storage.dart';
import 'package:hema_scoring_machine/widgets/fight_in_progress.dart';
import 'package:hema_scoring_machine/widgets/reset_button.dart';
import 'package:vibration/vibration.dart';

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

  @override
  void initState() {
    super.initState();
    _loadTimer();
  }

  Future<void> _loadTimer() async {
    final loaded = await loadTimerValue();
    setState(() {
      timer = loaded;
    });
  }

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
        elapsedTime: timer,
      );
    });
  }

  void startTimer() {
    _onStartPressed();
    countdown?.cancel();
    countdown = Timer.periodic(const Duration(milliseconds: 10), (t) {
      setState(() {
        if (timer.inMilliseconds > 0) {
          timer -= const Duration(milliseconds: 10);
          if (timer.isNegative) {
            timer = Duration.zero;
          }
        } else {
          t.cancel();
          running = false;

          Vibration.hasVibrator().then((hasVibrator) {
            Vibration.vibrate(duration: 1000, amplitude: 255);
          });
        }
      });
    });
    setState(() => running = true);
  }

  void stopTimer() {
    countdown?.cancel();
    setState(() => running = false);
  }

  void resetAll() async {
    fightLog.reset();
    final loadedTimer = await loadTimerValue();
    setState(() {
      leftScore = 0;
      rightScore = 0;
      leftWarning = 0;
      rightWarning = 0;
      leftCaution = 0;
      rightCaution = 0;
      doubleHits = 0;
      timer = loadedTimer;
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
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                TimerDisplay(
                  color: Colors.white,
                  time: formatTime(timer),
                  fontSize: 75,
                ),

                ActiveTimerBoard(leftScore: leftScore, rightScore: rightScore),

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
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: ResetButton(
                  label: "Reset",
                  color: Colors.red,
                  onPressed: resetAll,
                  onLongPress: _loadTimer,
                ),
              ),

              /// Timer display
              TimerDisplay(
                time: formatTime(timer),
                fontSize: 65,
                onDoubleTap: () async {
                  final newTime = await showTimeSelectDialog(context);

                  if (newTime != null) {
                    resetAll();
                    setState(() {
                      timer = newTime;
                    });
                  }
                },
              ),

              /// Scoreboard with swap fighters icon
              ScoreBoard(
                leftName: leftName,
                rightName: rightName,
                leftScore: leftScore,
                rightScore: rightScore,
                onLeftTap: () => _inc(() => leftScore, (v) => leftScore = v),
                onLeftLongPress: () =>
                    _dec(() => leftScore, (v) => leftScore = v),
                onRightTap: () => _inc(() => rightScore, (v) => rightScore = v),
                onRightLongPress: () =>
                    _dec(() => rightScore, (v) => rightScore = v),
                swapFighters: swapFighters,
              ),

              SizedBox(
                width: double.infinity,
                height: 150,
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

              const SizedBox(height: 10),

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

              const Spacer(),

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
                onDoublePlus: () =>
                    _inc(() => doubleHits, (v) => doubleHits = v),
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
            ],
          ),
        ),
      ),
    );
  }
}
