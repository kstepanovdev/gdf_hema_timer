import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
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
import '../modules/fight_log/fight_event.dart';
import '../modules/fight_log/fight_log.dart';
import '../modules/fight_log/fight_log_view.dart';
import '../l10n/gen/app_localizations.dart';
import '../modules/help/help_storage.dart';
import '../modules/settings/settings_storage.dart';
import '../theme/app_colors.dart';
import '../widgets/log_handle_panel.dart';
import '../widgets/help_dialog.dart';
import '../widgets/settings_drawer.dart';

class ScorePage extends StatefulWidget {
  const ScorePage({super.key});

  @override
  State<ScorePage> createState() => _ScorePageState();
}

class _ScorePageState extends State<ScorePage> {
  final fightLog = FightLog();
  final AudioPlayer _bruhPlayer = AudioPlayer();

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
    _maybeShowHelp();
    _initBruhPlayer();
  }

  /// Preloads the "bruh" sound so playback starts instantly. Without this,
  /// [AudioPlayer.play] would set the source (read the asset) on every hit,
  /// which caused a noticeable delay before the sound was heard.
  /// [ReleaseMode.stop] keeps the source loaded after playback completes
  /// (the default [ReleaseMode.release] frees it, reintroducing the delay).
  Future<void> _initBruhPlayer() async {
    await _bruhPlayer.setReleaseMode(ReleaseMode.stop);
    await _bruhPlayer.setSource(AssetSource('sounds/bruh.mp3'));
  }

  @override
  void dispose() {
    countdown?.cancel();
    _bruhPlayer.dispose();
    super.dispose();
  }

  /// Plays the "bruh" sound effect when Yehor's special is enabled.
  void _playBruh() {
    if (!yehorsSpecialEnabled.value) return;
    // Source is preloaded in [_initBruhPlayer]; rewind + resume replays it
    // immediately without re-preparing the player.
    _bruhPlayer.seek(Duration.zero);
    _bruhPlayer.resume();
  }

  Future<void> _maybeShowHelp() async {
    if (!await loadShowHelpOnLaunch()) return;
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) HelpDialog.show(context);
    });
  }

  Future<void> _loadTimer() async {
    final loaded = await loadTimerValue();
    setState(() => timer = loaded);
  }

  String _nameOf(Fighter fighter) =>
      fighter == Fighter.left ? leftName : rightName;

  void _changeScore(Fighter fighter, int newValue) {
    final delta = newValue - (fighter == Fighter.left ? leftScore : rightScore);
    if (delta == 0) return;
    setState(() {
      if (fighter == Fighter.left) {
        leftScore = newValue;
      } else {
        rightScore = newValue;
      }
    });
    fightLog.emit(
      ScoreChanged(
        timer,
        leftTotal: leftScore,
        rightTotal: rightScore,
      ),
    );
  }

  void _changePenalty(Fighter fighter, PenaltyKind kind, int newValue) {
    final old = switch ((fighter, kind)) {
      (Fighter.left, PenaltyKind.warning) => leftWarning,
      (Fighter.right, PenaltyKind.warning) => rightWarning,
      (Fighter.left, PenaltyKind.caution) => leftCaution,
      (Fighter.right, PenaltyKind.caution) => rightCaution,
    };
    final delta = newValue - old;
    if (delta == 0) return;
    setState(() {
      switch ((fighter, kind)) {
        case (Fighter.left, PenaltyKind.warning):
          leftWarning = newValue;
        case (Fighter.right, PenaltyKind.warning):
          rightWarning = newValue;
        case (Fighter.left, PenaltyKind.caution):
          leftCaution = newValue;
        case (Fighter.right, PenaltyKind.caution):
          rightCaution = newValue;
      }
    });
    fightLog.emit(
      PenaltyChanged(
        timer,
        fighter: _nameOf(fighter),
        kind: kind,
        delta: delta,
        total: newValue,
      ),
    );
  }

  void _changeDouble(int newValue) {
    final delta = newValue - doubleHits;
    if (delta == 0) return;
    if (delta > 0) _playBruh();
    setState(() => doubleHits = newValue);
    fightLog.emit(DoubleHitChanged(timer, delta: delta, total: newValue));
  }

  void startTimer() {
    fightLog.markStarted(timer);
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

  /// Clears scores and penalties for a new bout while keeping the current
  /// timer value untouched. Triggered by long-pressing the Reset button.
  void resetScoreOnly() {
    fightLog.reset();
    setState(() {
      leftScore = 0;
      rightScore = 0;
      leftWarning = 0;
      rightWarning = 0;
      leftCaution = 0;
      rightCaution = 0;
      doubleHits = 0;
    });
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
    final l10n = AppLocalizations.of(context);
    if (running) {
      return GestureDetector(
        onTap: stopTimer,
        child: Scaffold(
          backgroundColor: AppColors.stage,
          body: SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                TimerDisplay(
                  color: AppColors.onStage,
                  time: formatTime(timer),
                  fontSize: 60,
                ),
                ActiveTimerBoard(leftScore: leftScore, rightScore: rightScore),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: SizedBox(
                    child: BigButton(
                      label: l10n.stop,
                      color: AppColors.danger,
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
      drawer: const SettingsDrawer(),
      // The default 20px edge-drag zone sits entirely inside Android's system
      // gesture-nav (back-swipe) region, so the drawer never opens. Widen the
      // zone past the system-reserved inset so a swipe that starts just inboard
      // of the edge still opens Settings.
      drawerEdgeDragWidth:
          MediaQuery.of(context).systemGestureInsets.left + 80,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 10, 10, 20),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: ResetButton(
                          label: l10n.reset,
                          color: AppColors.danger,
                          onPressed: resetAll,
                          onLongPress: resetScoreOnly,
                        ),
                      ),
                      const SizedBox(height: 10),

                      TimerDisplay(
                        time: formatTime(timer),
                        fontSize: 60,
                        onLongPress: () async {
                          final newTime = await showTimeSelectDialog(context);
                          if (newTime != null) {
                            resetAll();
                            setState(() => timer = newTime);
                          }
                        },
                      ),

                      const SizedBox(height: 10),
                      ScoreBoard(
                        leftName: leftName,
                        rightName: rightName,
                        leftScore: leftScore,
                        rightScore: rightScore,
                        onLeftChanged: (v) => _changeScore(Fighter.left, v),
                        onRightChanged: (v) => _changeScore(Fighter.right, v),
                        swapFighters: swapFighters,
                      ),
                      const SizedBox(height: 10),

                      SizedBox(
                        width: double.infinity,
                        height: 150,
                        child: BigButton(
                          label: l10n.start,
                          color: AppColors.primary,
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
                            _changePenalty(Fighter.left, PenaltyKind.warning, v),
                        onRightWarningChanged: (v) => _changePenalty(
                          Fighter.right,
                          PenaltyKind.warning,
                          v,
                        ),
                        onLeftCautionChanged: (v) =>
                            _changePenalty(Fighter.left, PenaltyKind.caution, v),
                        onRightCautionChanged: (v) => _changePenalty(
                          Fighter.right,
                          PenaltyKind.caution,
                          v,
                        ),
                        onDoubleChanged: _changeDouble,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
