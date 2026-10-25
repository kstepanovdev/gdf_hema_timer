import 'dart:async';
import '../modules/bout_session/bout_session.dart';
import '../modules/bout_session/bout_session_controller.dart';
import '../modules/bout_session/bout_feedback.dart';
import 'package:flutter/material.dart';
import 'package:gdf_hema_timer/modules/timer/storage.dart';
import 'package:gdf_hema_timer/widgets/fight_in_progress.dart';
import 'package:gdf_hema_timer/widgets/reset_button.dart';

import '../widgets/big_button.dart';
import '../widgets/score_board.dart';
import '../widgets/timer_display.dart';
import '../widgets/time_control.dart';
import '../widgets/penalties_control.dart';
import '../utils/time_utils.dart';
import '../modules/fight_log/fight_event.dart';
import '../modules/fight_log/fight_log_view.dart';
import '../l10n/gen/app_localizations.dart';
import '../modules/help/help_storage.dart';
import '../theme/app_colors.dart';
import '../widgets/log_handle_panel.dart';
import '../widgets/help_dialog.dart';
import '../widgets/settings_drawer.dart';

class ScorePage extends StatefulWidget {
  const ScorePage({
    super.key,
    this.controller,
    this.feedback,
    this.boutContext,
    this.connectionStatus,
    this.onReview,
    this.beforeLeave,
    this.durableSession = false,
    this.judgingControls,
    this.scoreEditingEnabled = true,
    this.canReview = true,
    this.reviewLabel,
  });

  final BoutSessionController? controller;
  final BoutFeedback? feedback;
  final String? boutContext;
  final Widget? connectionStatus;
  final Future<void> Function()? onReview;
  final Future<bool> Function()? beforeLeave;
  final bool durableSession;
  final Widget? judgingControls;
  final bool scoreEditingEnabled, canReview;
  final String? reviewLabel;

  @override
  State<ScorePage> createState() => _ScorePageState();
}

class _ScorePageState extends State<ScorePage> with WidgetsBindingObserver {
  late final BoutSessionController session;
  late final BoutFeedback feedback;
  Timer? _refresh;
  bool _ready = false;
  bool _reviewing = false;
  bool _leaving = false;
  bool _confirmingLeave = false;

  int get leftScore => session.at(DisplaySide.left).score;
  int get rightScore => session.at(DisplaySide.right).score;
  int get leftWarning => session.at(DisplaySide.left).warning;
  int get rightWarning => session.at(DisplaySide.right).warning;
  int get leftCaution => session.at(DisplaySide.left).caution;
  int get rightCaution => session.at(DisplaySide.right).caution;
  int get doubleHits => session.session.mutualHits;
  String get leftName => session.at(DisplaySide.left).name;
  String get rightName => session.at(DisplaySide.right).name;
  Duration get timer => session.remaining;
  bool get running => session.running;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    session = widget.controller ?? BoutSessionController();
    feedback = widget.feedback ?? StandaloneBoutFeedback();
    session.addListener(_onSessionChanged);
    unawaited(feedback.prepare());
    _loadTimer();
    _maybeShowHelp();
  }

  void _onSessionChanged() {
    if (!mounted) return;
    if (running) {
      _refresh ??= Timer.periodic(const Duration(milliseconds: 16), (_) {
        if (session.refresh()) unawaited(feedback.timeExpired());
      });
    } else {
      _refresh?.cancel();
      _refresh = null;
    }
    setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) session.interrupt();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _refresh?.cancel();
    session.removeListener(_onSessionChanged);
    if (widget.controller == null) session.dispose();
    unawaited(feedback.dispose());
    super.dispose();
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
    if (!mounted) return;
    if (widget.controller == null) session.clock.setRemaining(loaded);
    setState(() => _ready = true);
  }

  void _changeDouble(int value) {
    if (value > doubleHits) unawaited(feedback.mutualHit());
    session.setMutualHits(value);
  }

  void startTimer() => session.start();
  void stopTimer() => session.pause();
  void resetScoreOnly() {
    if (!widget.scoreEditingEnabled) return;
    if (widget.onReview == null) {
      session.reset(duration: timer, keepTime: true);
      return;
    }
    session.setScore(DisplaySide.left, 0);
    session.setScore(DisplaySide.right, 0);
  }

  Future<void> resetAll() async {
    final duration = await loadTimerValue();
    if (mounted) _resetDuration(duration);
  }

  void _resetDuration(Duration duration) {
    if (!widget.scoreEditingEnabled) return;
    if (widget.onReview == null) {
      session.reset(duration: duration);
      return;
    }
    session.pause();
    session.clock.setRemaining(duration);
    session.adjustTime(Duration.zero);
    resetScoreOnly();
  }

  void swapFighters() => session.swapSides();

  Future<void> _review() async {
    if (_reviewing || widget.onReview == null) return;
    setState(() => _reviewing = true);
    stopTimer();
    try {
      await widget.onReview!();
    } finally {
      if (mounted) setState(() => _reviewing = false);
    }
  }

  Future<void> _leaveBout() async {
    if (_confirmingLeave || _leaving) return;
    _confirmingLeave = true;
    stopTimer();
    final l10n = AppLocalizations.of(context);
    final leave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.leaveBoutTitle),
        content: Text(
          widget.onReview == null
              ? l10n.leaveBoutMessage
              : widget.durableSession
              ? l10n.leaveSavedBout
              : l10n.leaveConnectedBout,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.leaveBout),
          ),
        ],
      ),
    );
    _confirmingLeave = false;
    if (leave == true &&
        widget.beforeLeave != null &&
        !await widget.beforeLeave!()) {
      return;
    }
    if (leave == true && mounted) {
      setState(() => _leaving = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).pop();
      });
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: _leaving,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) unawaited(_leaveBout());
    },
    child: _buildTimer(context),
  );

  Widget _buildTimer(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (!_ready) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (running) {
      return GestureDetector(
        onTap: stopTimer,
        child: Scaffold(
          backgroundColor: AppColors.stage,
          body: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      if (widget.boutContext != null)
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text(
                            widget.boutContext!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                      if (widget.connectionStatus != null)
                        widget.connectionStatus!,
                      if (widget.onReview != null)
                        Text(
                          '$leftName · $rightName',
                          style: const TextStyle(color: Colors.white),
                        ),
                      TimerDisplay(
                        color: AppColors.onStage,
                        time: formatTime(timer),
                        fontSize: 60,
                      ),
                      ActiveTimerBoard(
                        leftScore: leftScore,
                        rightScore: rightScore,
                      ),
                      if (widget.judgingControls != null)
                        widget.judgingControls!,
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
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.onReview == null ? l10n.standaloneMode : l10n.tournamentMode,
        ),
        actions: [
          IconButton(
            tooltip: l10n.leaveBout,
            onPressed: _leaveBout,
            icon: const Icon(Icons.exit_to_app),
          ),
        ],
      ),
      drawer: const SettingsDrawer(),
      // The default 20px edge-drag zone sits entirely inside Android's system
      // gesture-nav (back-swipe) region, so the drawer never opens. Widen the
      // zone past the system-reserved inset so a swipe that starts just inboard
      // of the edge still opens Settings.
      drawerEdgeDragWidth: MediaQuery.of(context).systemGestureInsets.left + 80,
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
                      if (widget.boutContext != null)
                        Padding(
                          padding: const EdgeInsets.all(8),
                          child: Text(
                            widget.boutContext!,
                            textAlign: TextAlign.center,
                          ),
                        ),
                      if (widget.connectionStatus != null)
                        widget.connectionStatus!,
                      if (session.interrupted)
                        Padding(
                          padding: const EdgeInsets.all(8),
                          child: Text(
                            l10n.interruptedClock,
                            key: const Key('clock-interrupted'),
                            semanticsLabel: l10n.interruptedClock,
                          ),
                        )
                      else if (session.fightLog.isEmpty &&
                          widget.onReview == null)
                        Padding(
                          padding: const EdgeInsets.all(8),
                          child: Text(l10n.sessionNotRestored),
                        ),
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
                            if (mounted) _resetDuration(newTime);
                          }
                        },
                      ),

                      const SizedBox(height: 10),
                      ScoreBoard(
                        leftName: leftName,
                        rightName: rightName,
                        leftScore: leftScore,
                        rightScore: rightScore,
                        onLeftChanged: (v) => widget.scoreEditingEnabled
                            ? session.setScore(DisplaySide.left, v)
                            : null,
                        onRightChanged: (v) => widget.scoreEditingEnabled
                            ? session.setScore(DisplaySide.right, v)
                            : null,
                        swapFighters: swapFighters,
                      ),
                      const SizedBox(height: 10),
                      if (widget.onReview != null)
                        FilledButton(
                          onPressed: _reviewing || !widget.canReview
                              ? null
                              : _review,
                          child: Text(widget.reviewLabel ?? l10n.reviewResult),
                        ),
                      SizedBox(
                        width: double.infinity,
                        height: 150,
                        child: BigButton(
                          label: l10n.start,
                          color: AppColors.primary,
                          fontSize: 40,
                          onPressed: widget.scoreEditingEnabled
                              ? startTimer
                              : () {},
                        ),
                      ),

                      GestureDetector(
                        onVerticalDragUpdate: (details) {
                          if (details.primaryDelta != null &&
                              details.primaryDelta! < -10) {
                            FightLogView.show(context, session.fightLog);
                          }
                        },
                        child: LogHandlePanel(fightLog: session.fightLog),
                      ),

                      const SizedBox(height: 10),

                      TimeControl(
                        onMinus1: () =>
                            session.adjustTime(const Duration(seconds: -1)),
                        onPlus3: () =>
                            session.adjustTime(const Duration(seconds: 3)),
                        onPlus5: () =>
                            session.adjustTime(const Duration(seconds: 5)),
                      ),

                      const SizedBox(height: 10),

                      if (widget.judgingControls != null)
                        widget.judgingControls!
                      else if (widget.onReview == null)
                        PenaltiesControl(
                          leftWarning: leftWarning,
                          rightWarning: rightWarning,
                          leftCaution: leftCaution,
                          rightCaution: rightCaution,
                          doubleHits: doubleHits,
                          onLeftWarningChanged: (v) => session.setPenalty(
                            DisplaySide.left,
                            PenaltyKind.warning,
                            v,
                          ),
                          onRightWarningChanged: (v) => session.setPenalty(
                            DisplaySide.right,
                            PenaltyKind.warning,
                            v,
                          ),
                          onLeftCautionChanged: (v) => session.setPenalty(
                            DisplaySide.left,
                            PenaltyKind.caution,
                            v,
                          ),
                          onRightCautionChanged: (v) => session.setPenalty(
                            DisplaySide.right,
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
