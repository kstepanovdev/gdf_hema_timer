/// Logical fighter identity is independent of the screen's left/right mapping.
enum FighterSlot { a, b }

enum DisplaySide { left, right }

class BoutFighter {
  const BoutFighter({
    required this.id,
    required this.name,
    this.score = 0,
    this.warning = 0,
    this.caution = 0,
  });

  final String id;
  final String name;
  final int score;
  final int warning;
  final int caution;

  BoutFighter copyWith({int? score, int? warning, int? caution}) => BoutFighter(
    id: id,
    name: name,
    score: score ?? this.score,
    warning: warning ?? this.warning,
    caution: caution ?? this.caution,
  );
}

/// Local scoring facts only: no winner, tournament rules or inferred sanctions.
class BoutSession {
  const BoutSession({
    required this.id,
    required this.a,
    required this.b,
    this.leftIsA = true,
    this.mutualHits = 0,
  });

  factory BoutSession.standalone(int number) => BoutSession(
    id: 'local-bout-$number',
    a: BoutFighter(id: 'local-bout-$number-a', name: 'F1'),
    b: BoutFighter(id: 'local-bout-$number-b', name: 'F2'),
  );

  final String id;
  final BoutFighter a;
  final BoutFighter b;
  final bool leftIsA;
  final int mutualHits;

  FighterSlot slotAt(DisplaySide side) =>
      (side == DisplaySide.left) == leftIsA ? FighterSlot.a : FighterSlot.b;
  BoutFighter fighter(FighterSlot slot) => slot == FighterSlot.a ? a : b;
  BoutFighter at(DisplaySide side) => fighter(slotAt(side));

  BoutSession copyWith({
    BoutFighter? a,
    BoutFighter? b,
    bool? leftIsA,
    int? mutualHits,
  }) => BoutSession(
    id: id,
    a: a ?? this.a,
    b: b ?? this.b,
    leftIsA: leftIsA ?? this.leftIsA,
    mutualHits: mutualHits ?? this.mutualHits,
  );
}
