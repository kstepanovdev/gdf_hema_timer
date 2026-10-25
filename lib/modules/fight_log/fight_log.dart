import 'fight_event.dart';

/// In-memory history. Corrections are kept alongside additions, not erased.
class FightLog {
  final List<FightEvent> _events = [];
  bool _started = false;

  List<FightEvent> get events => List.unmodifiable(_events);
  bool get isEmpty => _events.isEmpty;

  void emit(FightEvent event) => _events.add(event);

  void markStarted(Duration clock) {
    if (_started) return;
    _started = true;
    emit(FightStarted(clock));
  }

  void restore(List<FightEvent> events) {
    _events
      ..clear()
      ..addAll(events);
    _started = events.any((e) => e is FightStarted);
  }

  void reset() {
    _events.clear();
    _started = false;
  }
}
