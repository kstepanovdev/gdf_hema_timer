import 'dart:async';
import 'package:flutter/material.dart';
import 'package:gdf_hema_timer/modules/timer/storage.dart';
import 'package:gdf_hema_timer/widgets/fight_in_progress.dart';
import 'package:gdf_hema_timer/widgets/reset_button.dart';
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
    setState(() => timer = loaded);
  }

  void _onStartPressed() {
    setState(() {
      fightLog.startFight();
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
          if (timer.isNegative) timer = Duration.zero;
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

  void resetTimerOnly() async {
    await _loadTimer();
    fightLog.addSeparator();
    fightLog.addEvent("Next fight started", timer);
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
      final tmpScore = leftScore;
      leftScore = rightScore;
      rightScore = tmpScore;

      final tmpWarning = leftWarning;
      leftWarning = rightWarning;
      rightWarning = tmpWarning;

      final tmpCaution = leftCaution;
      leftCaution = rightCaution;
      rightCaution = tmpCaution;

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
                  fontSize: 65,
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
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Padding(
                // Move elements down slightly (top padding = 20)
                padding: const EdgeInsets.fromLTRB(10, 20, 10, 10),
                child: Column(
                  mainAxisSize:
                      MainAxisSize.min, // prevents bottom overflow gap
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: ResetButton(
                        label: "Reset",
                        color: Colors.red,
                        onPressed: resetAll,
                        onLongPress: resetTimerOnly,
                      ),
                    ),

                    TimerDisplay(
                      time: formatTime(timer),
                      fontSize: 65,
                      onLongPress: () async {
                        final newTime = await showTimeSelectDialog(context);
                        if (newTime != null) {
                          resetAll();
                          setState(() => timer = newTime);
                        }
                      },
                    ),

                    ScoreBoard(
                      leftName: leftName,
                      rightName: rightName,
                      leftScore: leftScore,
                      rightScore: rightScore,
                      onLeftChanged: (v) => setState(() => leftScore = v),
                      onRightChanged: (v) => setState(() => rightScore = v),
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
                        if (details.primaryDelta != null &&
                            details.primaryDelta! < -10) {
                          FightLogView.show(context, fightLog);
                        }
                      },
                      child: LogHandlePanel(fightLog: fightLog),
                    ),

                    const SizedBox(height: 10),

                    TimeControl(
                      onMinus1: () => setState(() {
                        timer = timer > const Duration(seconds: 1)
                            ? timer - const Duration(seconds: 1)
                            : Duration.zero;
                      }),
                      onPlus3: () =>
                          setState(() => timer += const Duration(seconds: 3)),
                      onPlus5: () =>
                          setState(() => timer += const Duration(seconds: 5)),
                    ),

                    const SizedBox(height: 10),

                    PenaltiesControl(
                      leftWarning: leftWarning,
                      rightWarning: rightWarning,
                      leftCaution: leftCaution,
                      rightCaution: rightCaution,
                      doubleHits: doubleHits,
                      onLeftWarningChanged: (v) =>
                          setState(() => leftWarning = v),
                      onRightWarningChanged: (v) =>
                          setState(() => rightWarning = v),
                      onLeftCautionChanged: (v) =>
                          setState(() => leftCaution = v),
                      onRightCautionChanged: (v) =>
                          setState(() => rightCaution = v),
                      onDoubleChanged: (v) => setState(() => doubleHits = v),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
