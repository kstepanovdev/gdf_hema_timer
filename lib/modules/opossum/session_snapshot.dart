import '../bout_session/bout_session.dart';
import '../fight_log/fight_event.dart';
import 'models.dart';

Json sessionJson(BoutSession s) => {
  'id': s.id,
  'a': fighterJson(s.a),
  'b': fighterJson(s.b),
  'left_is_a': s.leftIsA,
  'mutual_hits': s.mutualHits,
};
Json fighterJson(BoutFighter f) => {
  'id': f.id,
  'name': f.name,
  'score': f.score,
  'warning': f.warning,
  'caution': f.caution,
};
BoutFighter parseFighter(Json j) => BoutFighter(
  id: uuid(j['id']),
  name: text(j['name']),
  score: integer(j['score']),
  warning: integer(j['warning']),
  caution: integer(j['caution']),
);
BoutSession parseSession(Json j) => BoutSession(
  id: uuid(j['id']),
  a: parseFighter(object(j['a'])),
  b: parseFighter(object(j['b'])),
  leftIsA: j['left_is_a'] == true,
  mutualHits: integer(j['mutual_hits']),
);
Json eventJson(FightEvent e) => {
  'clock_ms': e.clock.inMilliseconds,
  ...switch (e) {
    FightStarted() => {'kind': 'started'},
    ScoreChanged() => {
      'kind': 'score',
      'fighter_id': e.fighterId,
      'fighter': e.fighter,
      'delta': e.delta,
      'score_a': e.scoreA,
      'score_b': e.scoreB,
      'left': e.leftTotal,
      'right': e.rightTotal,
    },
    PenaltyChanged() => {
      'kind': 'penalty',
      'fighter_id': e.fighterId,
      'fighter': e.fighter,
      'penalty': e.kind.name,
      'delta': e.delta,
      'total': e.total,
    },
    DoubleHitChanged() => {'kind': 'hits', 'delta': e.delta, 'total': e.total},
    SessionChanged() => {'kind': 'session', 'action': e.action.name},
  },
};
FightEvent parseEvent(Json j) {
  final clock = Duration(milliseconds: integer(j['clock_ms']));
  return switch (j['kind']) {
    'started' => FightStarted(clock),
    'score' => ScoreChanged(
      clock,
      fighterId: uuid(j['fighter_id']),
      fighter: text(j['fighter']),
      delta: j['delta'] as int,
      scoreA: integer(j['score_a']),
      scoreB: integer(j['score_b']),
      leftTotal: integer(j['left']),
      rightTotal: integer(j['right']),
    ),
    'penalty' => PenaltyChanged(
      clock,
      fighterId: uuid(j['fighter_id']),
      fighter: text(j['fighter']),
      kind: PenaltyKind.values.byName(text(j['penalty'])),
      delta: j['delta'] as int,
      total: integer(j['total']),
    ),
    'hits' => DoubleHitChanged(
      clock,
      delta: j['delta'] as int,
      total: integer(j['total']),
    ),
    'session' => SessionChanged(
      clock,
      action: SessionAction.values.byName(text(j['action'])),
    ),
    _ => throw const FormatException('session event'),
  };
}

class SessionSnapshot {
  SessionSnapshot({
    required this.origin,
    required this.nomination,
    required this.bout,
    required this.session,
    required this.remainingMs,
    required this.wasRunning,
    required this.events,
    required this.savedAt,
    required this.configuredMs,
    this.timingUncertain = false,
  }) {
    if (bout.id != session.id ||
        bout.a?.id != session.a.id ||
        bout.b?.id != session.b.id ||
        bout.nominationId != nomination.id ||
        bout.tournamentId != nomination.tournamentId ||
        remainingMs < 0 ||
        configuredMs < 0) {
      throw const FormatException('session identity');
    }
  }
  factory SessionSnapshot.fromJson(Json j) {
    if (j['schema_version'] != 1) throw const FormatException('session schema');
    return SessionSnapshot(
      origin: text(j['origin']),
      nomination: NominationRef.fromJson(object(j['nomination'])),
      bout: TimerBout.fromJson(object(j['bout'])),
      session: parseSession(object(j['session'])),
      remainingMs: integer(j['remaining_ms']),
      wasRunning: j['was_running'] == true,
      events: List.unmodifiable(
        array(j['events']).map((e) => parseEvent(object(e))),
      ),
      savedAt: DateTime.parse(text(j['saved_at'])),
      configuredMs: integer(j['configured_ms']),
      timingUncertain:
          j['timing_uncertain'] == true || j['was_running'] == true,
    );
  }
  final String origin;
  final NominationRef nomination;
  final TimerBout bout;
  final BoutSession session;
  final int remainingMs, configuredMs;
  final bool wasRunning, timingUncertain;
  final List<FightEvent> events;
  final DateTime savedAt;
  Json toJson() => {
    'schema_version': 1,
    'origin': origin,
    'nomination': nomination.toJson(),
    'bout': bout.toJson(),
    'session': sessionJson(session),
    'remaining_ms': remainingMs,
    'configured_ms': configuredMs,
    'was_running': wasRunning,
    'timing_uncertain': timingUncertain,
    'events': events.map(eventJson).toList(),
    'saved_at': savedAt.toUtc().toIso8601String(),
  };
}
