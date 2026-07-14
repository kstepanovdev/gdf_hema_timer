import 'fight_event.dart';

/// The recorded history of a bout, as a list of structured [FightEvent]s.
///
/// Actions are reported through [emit] — a single, uniform entry point.
/// Recording *policy* lives here, not in the UI: correction actions (a negative
/// delta from a long-press) are emitted like anything else but are intentionally
/// **not** kept in the persisted history.
class FightLog {
  final List<FightEvent> _events = [];
  bool _started = false;

  List<FightEvent> get events => List.unmodifiable(_events);
  bool get isEmpty => _events.isEmpty;

  /// Emits an event into the log. Penalty/double-hit corrections (negative
  /// deltas) pass through here but are not appended to the recorded history.
  /// Score changes are always kept — including decrements — since each entry
  /// records the resulting scoreline, so a decrement reads as a valid state.
  void emit(FightEvent event) {
    if (_isCorrection(event)) return;
    _events.add(event);
  }

  /// Records the one-time "fight started" marker on the first start of a bout.
  /// No-op on subsequent starts until the log is [reset].
  void markStarted(Duration clock) {
    if (_started) return;
    _started = true;
    emit(FightStarted(clock));
  }

  /// Clears the history and arms [markStarted] again for a fresh bout.
  void reset() {
    _events.clear();
    _started = false;
  }

  static bool _isCorrection(FightEvent event) => switch (event) {
    ScoreChanged() => false,
    PenaltyChanged(:final delta) => delta < 0,
    DoubleHitChanged(:final delta) => delta < 0,
    FightStarted() => false,
  };
}
