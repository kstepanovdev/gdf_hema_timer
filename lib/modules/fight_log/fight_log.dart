import 'package:hema_scoring_machine/utils/time_utils.dart';

class FightLog {
  final List<String> _events = [];
  DateTime? _startTime;

  // Previous snapshot
  int _prevLeftScore = 0;
  int _prevRightScore = 0;
  int _prevLeftWarning = 0;
  int _prevRightWarning = 0;
  int _prevLeftCaution = 0;
  int _prevRightCaution = 0;
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
    _events.add("$time - $message");
  }

  String _formattedElapsed() {
    if (_startTime == null) return "0:00.000";
    final diff = DateTime.now().difference(_startTime!);
    return formatTime(diff);
  }

  /// Diff-based snapshot
  void logDiff({
    required int leftScore,
    required int rightScore,
    required int leftWarning,
    required int rightWarning,
    required int leftCaution,
    required int rightCaution,
    required int doubleHits,
    required String leftName,
    required String rightName,
  }) {
    // Score changed?
    if (leftScore != _prevLeftScore || rightScore != _prevRightScore) {
      addEvent("$leftScore:$rightScore");
    }

    // Left warns diff
    if (leftWarning > _prevLeftWarning) {
      final diff = leftWarning - _prevLeftWarning;
      for (int i = 0; i < diff; i++) {
        addEvent("warning to $leftName");
      }
    }

    // Right warns diff
    if (rightWarning > _prevRightWarning) {
      final diff = rightWarning - _prevRightWarning;
      for (int i = 0; i < diff; i++) {
        addEvent("warning to $rightName");
      }
    }

    if (leftCaution > _prevLeftCaution) {
      final diff = leftCaution - _prevLeftCaution;
      for (int i = 0; i < diff; i++) {
        addEvent("caution to $leftName");
      }
    }

    if (rightCaution > _prevRightCaution) {
      final diff = rightCaution - _prevRightCaution;
      for (int i = 0; i < diff; i++) {
        addEvent("caution to $rightName");
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
    _prevLeftWarning = leftWarning;
    _prevRightWarning = rightWarning;
    _prevLeftCaution = leftCaution;
    _prevRightCaution = rightCaution;
    _prevDoubleHits = doubleHits;
  }

  void reset() {
    _prevLeftScore = _prevRightScore = 0;
    _prevLeftWarning = _prevRightWarning = 0;
    _prevDoubleHits = 0;
    _events.clear();
  }

  bool get isEmpty => _events.isEmpty;
}
