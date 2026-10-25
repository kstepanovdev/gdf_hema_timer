/// Monotonic countdown. Refresh callbacks only read time; they never count it.
///
/// Lifecycle interruptions are deliberately paused by the session controller.
/// No wall-clock timestamp is used to guess time after a restart or suspension.
class FightClock {
  FightClock(Duration duration, {Duration Function()? elapsed})
    : _remaining = _valid(duration),
      _elapsed = elapsed ?? _stopwatchSource();

  final Duration Function() _elapsed;
  Duration _remaining;
  Duration? _startedAt;

  static Duration Function() _stopwatchSource() {
    final watch = Stopwatch()..start();
    return () => watch.elapsed;
  }

  static Duration _valid(Duration value) =>
      value.isNegative ? Duration.zero : value;

  bool get running => _startedAt != null && remaining > Duration.zero;

  Duration get remaining {
    final startedAt = _startedAt;
    return startedAt == null
        ? _remaining
        : _valid(_remaining - (_elapsed() - startedAt));
  }

  void start() {
    if (_startedAt != null || remaining == Duration.zero) return;
    _startedAt = _elapsed();
  }

  void pause() {
    _remaining = remaining;
    _startedAt = null;
  }

  void setRemaining(Duration value) {
    final wasRunning = running;
    _remaining = _valid(value);
    _startedAt = wasRunning && _remaining > Duration.zero ? _elapsed() : null;
  }
}
