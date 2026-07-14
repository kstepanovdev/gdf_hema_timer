/// Which fighter an event refers to.
enum Fighter { left, right }

/// The kind of penalty a [PenaltyChanged] event carries.
enum PenaltyKind { warning, caution }

/// A single, structured thing that happened during a bout.
///
/// Events are typed and carry the raw data (who, what, resulting total, and the
/// clock reading when it happened) rather than pre-formatted text, so they can
/// be re-localized, re-styled, or replayed. Rendering is a pure function of the
/// event — see `fight_event_formatter.dart`.
///
/// Sealed so the formatter's `switch` is exhaustive at compile time.
sealed class FightEvent {
  /// The on-screen timer reading (time remaining) when the event occurred.
  final Duration clock;

  const FightEvent(this.clock);
}

/// The bout's timer was started for the first time.
final class FightStarted extends FightEvent {
  const FightStarted(super.clock);
}

/// The score changed, captured as the resulting scoreline
/// ([leftTotal] : [rightTotal]) at the moment it happened.
///
/// The full scoreline is snapshotted so the log can show the score as it stood,
/// which stays correct regardless of any later side swaps. Decrements are
/// recorded too — each entry is a valid state, not a delta.
final class ScoreChanged extends FightEvent {
  final int leftTotal;
  final int rightTotal;

  const ScoreChanged(
    super.clock, {
    required this.leftTotal,
    required this.rightTotal,
  });
}

/// A fighter received/lost a penalty of [kind], changing by [delta] (to [total]).
///
/// [fighter] is the fighter's name captured when the event occurred.
final class PenaltyChanged extends FightEvent {
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

/// The double-hit counter changed by [delta] (to [total]).
final class DoubleHitChanged extends FightEvent {
  final int delta;
  final int total;

  const DoubleHitChanged(
    super.clock, {
    required this.delta,
    required this.total,
  });
}
