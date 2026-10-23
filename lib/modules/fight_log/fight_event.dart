enum Fighter { left, right }

enum PenaltyKind { warning, caution }

/// Something that happened during a bout, stamped with the timer reading
/// (time remaining). Events hold raw data, not text, so they can be
/// re-localized; see `fight_event_formatter.dart`.
sealed class FightEvent {
  final Duration clock;

  const FightEvent(this.clock);
}

final class FightStarted extends FightEvent {
  const FightStarted(super.clock);
}

/// The scoreline after the change.
final class ScoreChanged extends FightEvent {
  final int leftTotal;
  final int rightTotal;

  const ScoreChanged(
    super.clock, {
    required this.leftTotal,
    required this.rightTotal,
  });
}

final class PenaltyChanged extends FightEvent {
  /// The fighter's name at the time of the event.
  final String fighter;
  final PenaltyKind kind;
  final int delta;
  final int total;

  const PenaltyChanged(
    super.clock, {
    required this.fighter,
    required this.kind,
    required this.delta,
    required this.total,
  });
}

final class DoubleHitChanged extends FightEvent {
  final int delta;
  final int total;

  const DoubleHitChanged(
    super.clock, {
    required this.delta,
    required this.total,
  });
}
