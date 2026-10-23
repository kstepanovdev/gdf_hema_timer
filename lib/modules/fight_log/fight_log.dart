import 'fight_event.dart';

/// The recorded history of a bout.
///
/// Penalty and double-hit corrections (negative deltas from a long-press) are
/// dropped. Score decrements are kept: each entry is the resulting scoreline,
/// so it's still a valid state.
class FightLog {
  final List<FightEvent> _events = [];
  bool _started = false;

  List<FightEvent> get events => List.unmodifiable(_events);

  void emit(FightEvent event) {
    if (event case PenaltyChanged(delta: < 0) || DoubleHitChanged(delta: < 0)) {
      return;
    }
    _events.add(event);
  }

  /// Records "fight started" on the first start since the last [reset].
  void markStarted(Duration clock) {
    if (_started) return;
    _started = true;
    emit(FightStarted(clock));
  }

  void reset() {
    _events.clear();
    _started = false;
  }
}
