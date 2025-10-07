import 'package:gdf_hema_timer/modules/timer/storage.dart';
import 'package:gdf_hema_timer/utils/time_utils.dart';

class FightLog {
  final List<String> _events = [];

  // Previous snapshot
  int _prevLeftScore = 0;
  int _prevRightScore = 0;
  int _prevLeftWarning = 0;
  int _prevRightWarning = 0;
  int _prevLeftCaution = 0;
  int _prevRightCaution = 0;
  int _prevDoubleHits = 0;

  bool _fightStarted = false;

  List<String> get events => List.unmodifiable(_events);

  void startFight() async {
    if (!_fightStarted) {
      reset();
      Duration fightTimeFormat = await loadTimerValue();
      addEvent("Fight started", fightTimeFormat);
    }
    _fightStarted = true;
  }

  void addSeparator() {
    _events.add("--------------------------");
  }

  void addEvent(String message, Duration elapsedTime) async {
    Duration fightTimeFormat = await loadTimerValue();
    final diff = formatTime(fightTimeFormat - elapsedTime);
    _events.add("$diff - $message");
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
    required Duration elapsedTime,
  }) {
    // Score changed?
    if (leftScore != _prevLeftScore || rightScore != _prevRightScore) {
      addEvent("$leftScore:$rightScore", elapsedTime);
    }

    // Left warns diff
    if (leftWarning > _prevLeftWarning) {
      final diff = leftWarning - _prevLeftWarning;
      for (int i = 0; i < diff; i++) {
        addEvent("warning to $leftName", elapsedTime);
      }
    }

    // Right warns diff
    if (rightWarning > _prevRightWarning) {
      final diff = rightWarning - _prevRightWarning;
      for (int i = 0; i < diff; i++) {
        addEvent("warning to $rightName", elapsedTime);
      }
    }

    if (leftCaution > _prevLeftCaution) {
      final diff = leftCaution - _prevLeftCaution;
      for (int i = 0; i < diff; i++) {
        addEvent("caution to $leftName", elapsedTime);
      }
    }

    if (rightCaution > _prevRightCaution) {
      final diff = rightCaution - _prevRightCaution;
      for (int i = 0; i < diff; i++) {
        addEvent("caution to $rightName", elapsedTime);
      }
    }

    // Double hits diff
    if (doubleHits > _prevDoubleHits) {
      final diff = doubleHits - _prevDoubleHits;
      for (int i = 0; i < diff; i++) {
        addEvent("double hit #${i + 1}", elapsedTime);
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
    _fightStarted = false;
    _events.clear();
  }

  bool get isEmpty => _events.isEmpty;
}
