class FightLog {
  final List<String> _events = [];
  DateTime? _startTime;

  // Previous snapshot
  int _prevLeftScore = 0;
  int _prevRightScore = 0;
  int _prevLeftWarn = 0;
  int _prevRightWarn = 0;
  int _prevDoubleHits = 0;

  List<String> get events => List.unmodifiable(_events);

  void startFight() {
    if (_startTime == null) {
      reset();
      addEvent("Fight started");
      _startTime = DateTime.now();
    }
  }

  void addEvent(String message) {
    final time = _formattedElapsed();
    _events.add("$time $message");
  }

  String _formattedElapsed() {
    if (_startTime == null) return "0:00";
    final diff = DateTime.now().difference(_startTime!);
    final minutes = diff.inMinutes;
    final seconds = (diff.inSeconds % 60).toString().padLeft(2, '0');
    return "$minutes:$seconds";
  }

  /// Diff-based snapshot
  void logDiff({
    required int leftScore,
    required int rightScore,
    required int leftWarn,
    required int rightWarn,
    required int doubleHits,
    required String leftName,
    required String rightName,
  }) {
    // Score changed?
    if (leftScore != _prevLeftScore || rightScore != _prevRightScore) {
      addEvent("$leftScore:$rightScore");
    }

    // Left warns diff
    if (leftWarn > _prevLeftWarn) {
      final diff = leftWarn - _prevLeftWarn;
      for (int i = 0; i < diff; i++) {
        addEvent("warning to $leftName");
      }
    }

    // Right warns diff
    if (rightWarn > _prevRightWarn) {
      final diff = rightWarn - _prevRightWarn;
      for (int i = 0; i < diff; i++) {
        addEvent("warning to $rightName");
      }
    }

    // Double hits diff
    if (doubleHits > _prevDoubleHits) {
      final diff = doubleHits - _prevDoubleHits;
      for (int i = 0; i < diff; i++) {
        addEvent("double hit");
      }
    }

    // Update snapshot
    _prevLeftScore = leftScore;
    _prevRightScore = rightScore;
    _prevLeftWarn = leftWarn;
    _prevRightWarn = rightWarn;
    _prevDoubleHits = doubleHits;
  }

  void reset() {
    _prevLeftScore = _prevRightScore = 0;
    _prevLeftWarn = _prevRightWarn = 0;
    _prevDoubleHits = 0;
    _events.clear();
  }

  bool get isEmpty => _events.isEmpty;
}
