import 'package:flutter/foundation.dart';
import '../fight_log/fight_event.dart';
import '../fight_log/fight_log.dart';
import 'bout_session.dart';
import 'fight_clock.dart';

/// Owns one local bout. No network, preferences, platform plugins or scheduling.
/// The view schedules refreshes; [FightClock] measures elapsed time separately.
class BoutSessionController extends ChangeNotifier {
  BoutSessionController({
    Duration duration = const Duration(seconds: 90),
    Duration Function()? elapsed,
    BoutSession? initialSession,
  }) : clock = FightClock(duration, elapsed: elapsed),
       _initialSession = initialSession,
       _session = initialSession ?? BoutSession.standalone(1);

  final FightClock clock;
  final FightLog fightLog = FightLog();
  final BoutSession? _initialSession;
  BoutSession _session;
  int _boutNumber = 1;
  bool _started = false;
  bool _ticking = false;
  bool _interrupted = false;

  void restore({
    required BoutSession session,
    required Duration remaining,
    required List<FightEvent> events,
    required bool timingUncertain,
  }) {
    if (session.id != _session.id ||
        session.a.id != _session.a.id ||
        session.b.id != _session.b.id) {
      throw StateError('Recovered pairing mismatch');
    }
    clock.pause();
    clock.setRemaining(remaining);
    _session = session;
    _ticking = false;
    _started = events.any((e) => e is FightStarted);
    _interrupted = timingUncertain;
    fightLog.restore(events);
    notifyListeners();
  }

  BoutSession get session => _session;
  Duration get remaining => clock.remaining;
  bool get running => clock.running;
  bool get interrupted => _interrupted;
  BoutFighter at(DisplaySide side) => _session.at(side);

  /// Apply server facts without emitting speculative local penalty events.
  /// The captured fighters and visual side mapping cannot change on refresh.
  void applyAuthoritativeSession(BoutSession next, {bool pauseClock = false}) {
    if (next.id != _session.id ||
        next.a.id != _session.a.id ||
        next.b.id != _session.b.id) {
      throw StateError('Authoritative pairing changed');
    }
    if (pauseClock) pause();
    _session = next.copyWith(leftIsA: _session.leftIsA);
    notifyListeners();
  }

  void _action(SessionAction action) =>
      fightLog.emit(SessionChanged(remaining, action: action));

  void setScore(DisplaySide side, int value) {
    if (value < 0) return;
    final fighter = at(side);
    if (fighter.score == value) return;
    _replace(side, fighter.copyWith(score: value));
    fightLog.emit(
      ScoreChanged(
        remaining,
        fighterId: fighter.id,
        fighter: fighter.name,
        delta: value - fighter.score,
        scoreA: _session.a.score,
        scoreB: _session.b.score,
        leftTotal: at(DisplaySide.left).score,
        rightTotal: at(DisplaySide.right).score,
      ),
    );
    notifyListeners();
  }

  void setPenalty(DisplaySide side, PenaltyKind kind, int value) {
    if (value < 0) return;
    final fighter = at(side);
    final old = kind == PenaltyKind.warning ? fighter.warning : fighter.caution;
    if (old == value) return;
    _replace(
      side,
      kind == PenaltyKind.warning
          ? fighter.copyWith(warning: value)
          : fighter.copyWith(caution: value),
    );
    fightLog.emit(
      PenaltyChanged(
        remaining,
        fighterId: fighter.id,
        fighter: fighter.name,
        kind: kind,
        delta: value - old,
        total: value,
      ),
    );
    notifyListeners();
  }

  void _replace(DisplaySide side, BoutFighter fighter) {
    _session = _session.slotAt(side) == FighterSlot.a
        ? _session.copyWith(a: fighter)
        : _session.copyWith(b: fighter);
  }

  void setMutualHits(int value) {
    if (value < 0 || value == _session.mutualHits) return;
    final delta = value - _session.mutualHits;
    _session = _session.copyWith(mutualHits: value);
    fightLog.emit(DoubleHitChanged(remaining, delta: delta, total: value));
    notifyListeners();
  }

  void swapSides() {
    _session = _session.copyWith(leftIsA: !_session.leftIsA);
    _action(SessionAction.sidesSwapped);
    notifyListeners();
  }

  void start() {
    if (running || remaining == Duration.zero) return;
    if (!_started) {
      fightLog.markStarted(remaining);
    } else {
      _action(SessionAction.resumed);
    }
    _started = true;
    _interrupted = false;
    _ticking = true;
    clock.start();
    notifyListeners();
  }

  void pause() {
    if (!_ticking) return;
    if (!running) {
      refresh();
      return;
    }
    clock.pause();
    _ticking = false;
    _action(SessionAction.paused);
    notifyListeners();
  }

  /// Lost foreground/screen continuity: pause, mark uncertain, never auto-resume.
  void interrupt() {
    if (!_ticking) return;
    clock.pause();
    _ticking = false;
    _interrupted = true;
    _action(SessionAction.interrupted);
    notifyListeners();
  }

  /// Returns true once when an actively observed countdown reaches zero.
  bool refresh() {
    if (!_ticking) return false;
    final expired = !running;
    if (expired) {
      clock.pause();
      _ticking = false;
      _action(SessionAction.elapsed);
    }
    notifyListeners();
    return expired;
  }

  void adjustTime(Duration delta) {
    clock.setRemaining(remaining + delta);
    _action(SessionAction.timeAdjusted);
    notifyListeners();
  }

  void reset({required Duration duration, bool keepTime = false}) {
    clock.pause();
    _ticking = false;
    if (!keepTime) {
      clock.setRemaining(duration);
      _interrupted = false;
    }
    _session = _initialSession ?? BoutSession.standalone(++_boutNumber);
    _started = false;
    fightLog.reset();
    _action(SessionAction.reset);
    notifyListeners();
  }
}
