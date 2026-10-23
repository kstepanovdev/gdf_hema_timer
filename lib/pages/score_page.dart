import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:vibration/vibration.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../l10n/gen/app_localizations.dart';
import '../modules/fight_log/fight_event.dart';
import '../modules/fight_log/fight_log.dart';
import '../modules/fight_log/fight_log_view.dart';
import '../modules/settings/settings_storage.dart';
import '../theme/app_colors.dart';
import '../utils/time_utils.dart';
import '../widgets/big_button.dart';
import '../widgets/fight_in_progress.dart';
import '../widgets/help_dialog.dart';
import '../widgets/log_handle_panel.dart';
import '../widgets/penalties_control.dart';
import '../widgets/score_board.dart';
import '../widgets/settings_drawer.dart';
import '../widgets/time_control.dart';
import '../widgets/timer_display.dart';

class ScorePage extends StatefulWidget {
  const ScorePage({super.key});

  @override
  State<ScorePage> createState() => _ScorePageState();
}

/// One fighter's tallies.
class _Side {
  _Side(this.name);
  final String name;
  int score = 0;
  final penalties = {for (final kind in PenaltyKind.values) kind: 0};
}

class _ScorePageState extends State<ScorePage> {
  static const _tick = Duration(milliseconds: 10);

  final fightLog = FightLog();
  final _bruhPlayer = AudioPlayer();

  var _left = _Side('F1');
  var _right = _Side('F2');
  int doubleHits = 0;

  Duration timer = savedTimerDuration;
  Timer? countdown;
  bool get running => countdown?.isActive ?? false;

  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    // Keep the screen awake while the app is in use, so the lock screen can't
    // get in the way of scoring or stopping the clock (issue #7). The OS only
    // honours this in the foreground and may drop it in the background, so
    // re-request it on every return to the app.
    WakelockPlus.enable();
    _lifecycle = AppLifecycleListener(onResume: WakelockPlus.enable);
    if (showHelpOnLaunch) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) HelpDialog.show(context);
      });
    }
    // Preload the sound and keep it loaded after playback (the default
    // ReleaseMode.release frees it), so a Double hit plays without delay.
    _bruhPlayer
      ..setReleaseMode(ReleaseMode.stop)
      ..setSource(AssetSource('sounds/bruh.mp3'));
  }

  @override
  void dispose() {
    countdown?.cancel();
    _lifecycle.dispose();
    WakelockPlus.disable();
    _bruhPlayer.dispose();
    super.dispose();
  }

  _Side _side(Fighter fighter) => fighter == Fighter.left ? _left : _right;

  void _changeScore(Fighter fighter, int value) {
    final side = _side(fighter);
    if (value == side.score) return;
    setState(() => side.score = value);
    fightLog.emit(
      ScoreChanged(timer, leftTotal: _left.score, rightTotal: _right.score),
    );
  }

  void _changePenalty(Fighter fighter, PenaltyKind kind, int value) {
    final side = _side(fighter);
    final delta = value - side.penalties[kind]!;
    if (delta == 0) return;
    setState(() => side.penalties[kind] = value);
    fightLog.emit(
      PenaltyChanged(
        timer,
        fighter: side.name,
        kind: kind,
        delta: delta,
        total: value,
      ),
    );
  }

  void _changeDouble(int value) {
    final delta = value - doubleHits;
    if (delta == 0) return;
    if (delta > 0 && yehorsSpecialEnabled.value) {
      _bruhPlayer
        ..seek(Duration.zero)
        ..resume();
    }
    setState(() => doubleHits = value);
    fightLog.emit(DoubleHitChanged(timer, delta: delta, total: value));
  }

  void startTimer() {
    fightLog.markStarted(timer);
    // Derive the remaining time from a stopwatch rather than subtracting a
    // fixed step per tick, so late or dropped ticks don't slow the clock.
    final startedWith = timer;
    final elapsed = clock.stopwatch()..start();
    countdown?.cancel();
    setState(() {
      countdown = Timer.periodic(_tick, (_) {
        final remaining = startedWith - elapsed.elapsed;
        if (remaining > Duration.zero) {
          setState(() => timer = remaining);
        } else {
          timer = Duration.zero;
          stopTimer();
          Vibration.hasVibrator().then((has) {
            if (has) Vibration.vibrate(duration: 1000, amplitude: 255);
          });
        }
      });
    });
  }

  void stopTimer() {
    setState(() => countdown?.cancel());
  }

  /// Clears scores and penalties; keeps the timer unless [timer] is given.
  void _reset({Duration? timer}) {
    fightLog.reset();
    setState(() {
      _left = _Side(_left.name);
      _right = _Side(_right.name);
      doubleHits = 0;
      if (timer != null) this.timer = timer;
    });
  }

  void _adjustTimer(int seconds) {
    final adjusted = timer + Duration(seconds: seconds);
    setState(() => timer = adjusted.isNegative ? Duration.zero : adjusted);
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
                ActiveTimerBoard(
                  leftScore: _left.score,
                  rightScore: _right.score,
                ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: BigButton(
                    label: l10n.stop,
                    color: AppColors.danger,
                    fontSize: 28,
                    onPressed: stopTimer,
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
      // The default 20px edge-drag zone sits inside Android's back-swipe
      // region, so the drawer would never open; widen it past the inset.
      drawerEdgeDragWidth: MediaQuery.of(context).systemGestureInsets.left + 80,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 10, 10, 20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    BigButton(
                      label: l10n.reset,
                      color: AppColors.danger,
                      fontSize: 35,
                      width: double.infinity,
                      onPressed: () => _reset(timer: savedTimerDuration),
                      onLongPress: _reset,
                    ),
                    const SizedBox(height: 20),
                    TimerDisplay(
                      time: formatTime(timer),
                      fontSize: 60,
                      onLongPress: () async {
                        final newTime = await showTimeSelectDialog(context);
                        if (newTime != null) _reset(timer: newTime);
                      },
                    ),
                    const SizedBox(height: 10),
                    ScoreBoard(
                      leftScore: _left.score,
                      rightScore: _right.score,
                      onLeftChanged: (v) => _changeScore(Fighter.left, v),
                      onRightChanged: (v) => _changeScore(Fighter.right, v),
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
                    LogHandlePanel(
                      onOpen: () => showFightLog(context, fightLog),
                    ),
                    const SizedBox(height: 10),
                    TimeControl(onAdjust: _adjustTimer),
                    const SizedBox(height: 10),
                    PenaltiesControl(
                      penalty: (fighter, kind) =>
                          _side(fighter).penalties[kind]!,
                      onPenaltyChanged: _changePenalty,
                      doubleHits: doubleHits,
                      onDoubleChanged: _changeDouble,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
