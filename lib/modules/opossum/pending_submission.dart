import 'dart:math';
import '../bout_session/bout_session.dart';
import 'models.dart';
import 'judging.dart';

Json _judgePayload(Json event) {
  final kind = text(event['type']);
  if (!['REMARK', 'WARNING', 'MUTUAL_HIT'].contains(kind) ||
      event.keys.any(
        (key) => !['type', 'participant_id', 'score_snapshot'].contains(key),
      )) {
    throw const FormatException('judge event fields');
  }
  if (kind != 'MUTUAL_HIT') {
    if (event['score_snapshot'] != null) {
      throw const FormatException('discipline score snapshot');
    }
    return Map<String, dynamic>.unmodifiable({
      'type': kind,
      'participant_id': uuid(event['participant_id']),
    });
  }
  if (event['participant_id'] != null) {
    throw const FormatException('mutual-hit fighter');
  }
  final scores = event['score_snapshot'] == null
      ? null
      : object(event['score_snapshot']);
  return Map<String, dynamic>.unmodifiable({
    'type': kind,
    if (scores != null)
      'score_snapshot': Map<String, dynamic>.unmodifiable({
        'score_a': integer(scores['score_a']),
        'score_b': integer(scores['score_b']),
      }),
  });
}

String newRequestId() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 15) | 64;
  bytes[8] = (bytes[8] & 63) | 128;
  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}

enum SubmissionState {
  pending,
  sending,
  accepted,
  uncertain,
  authentication,
  forbidden,
  conflict,
  rejected,
  rateLimited,
}

/// Immutable request envelope. Serializable independently of HTTP/UI/storage.
/// No credentials; an origin prevents accidental replay to a different server.
class PendingSubmission {
  PendingSubmission.fromJson(Json json)
    : origin = text(json['origin']),
      tournamentId = uuid(json['tournament_id']),
      nominationId = uuid(json['nomination_id']),
      boutId = uuid(json['bout_id']),
      version = integer(json['version']),
      fighterAId = uuid(json['fighter_a_id']),
      fighterBId = uuid(json['fighter_b_id']),
      scoreA = integer(json['score_a']),
      scoreB = integer(json['score_b']),
      idempotencyKey = uuid(json['idempotency_key']),
      clientEventId = uuid(json['client_event_id']),
      deviceId = uuid(json['device_id']),
      submittedAt = text(json['submitted_at']),
      judgeEvent = json['judge_event'] == null
          ? null
          : _judgePayload(object(json['judge_event'])),
      judgingRevision = json['judging_revision'] as String?,
      judgingPolicy = json['judging_policy'] as String? {
    if (json['schema_version'] != 1 ||
        DateTime.tryParse(submittedAt) == null ||
        fighterAId == fighterBId) {
      throw const FormatException('submission');
    }
    if (judgeEvent != null) {
      if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(judgingRevision ?? '') ||
          judgingPolicy == null ||
          !['REMARK', 'WARNING', 'MUTUAL_HIT'].contains(judgeEvent!['type'])) {
        throw const FormatException('judge event');
      }
      if (judgeEvent!['type'] != 'MUTUAL_HIT' &&
          ![fighterAId, fighterBId].contains(judgeEvent!['participant_id'])) {
        throw const FormatException('judge fighter');
      }
    }
  }
  factory PendingSubmission.judge({
    required String origin,
    required JudgingState judging,
    required BoutSession session,
    required JudgeEventKind kind,
    String? fighterId,
    required String deviceId,
    String Function()? createId,
    DateTime Function()? now,
  }) {
    if (judging.bout.id != session.id ||
        judging.bout.a?.id != session.a.id ||
        judging.bout.b?.id != session.b.id ||
        !judging.judgeWrite) {
      throw const FormatException('judge pairing/permission');
    }
    final ids = createId ?? newRequestId;
    return PendingSubmission.fromJson({
      'schema_version': 1,
      'origin': origin,
      'tournament_id': judging.bout.tournamentId,
      'nomination_id': judging.bout.nominationId,
      'bout_id': session.id,
      'version': judging.bout.version,
      'fighter_a_id': session.a.id,
      'fighter_b_id': session.b.id,
      'score_a': session.a.score,
      'score_b': session.b.score,
      'device_id': deviceId,
      'idempotency_key': ids(),
      'client_event_id': ids(),
      'submitted_at': (now ?? DateTime.now)().toUtc().toIso8601String(),
      'judging_revision': judging.revision,
      'judging_policy': judging.policyKey,
      'judge_event': {
        'type': judgeEventName(kind),
        if (kind != JudgeEventKind.mutualHit) 'participant_id': fighterId,
        if (kind == JudgeEventKind.mutualHit &&
            judging.scoreSnapshotWrite &&
            judging.bout.stageType != 'SINGLE_ELIMINATION')
          'score_snapshot': {
            'score_a': session.a.score,
            'score_b': session.b.score,
          },
      },
    });
  }
  factory PendingSubmission.confirm({
    required String origin,
    required TimerBout bout,
    required BoutSession session,
    required String deviceId,
    String Function()? createId,
    DateTime Function()? now,
  }) {
    if (!bout.writable ||
        bout.a!.id != session.a.id ||
        bout.b!.id != session.b.id ||
        session.id != bout.id ||
        bout.effectiveHits != session.mutualHits) {
      throw const FormatException('unsupported or non-writable result');
    }
    final ids = createId ?? newRequestId;
    if (bout.stageType == 'SINGLE_ELIMINATION') {
      final phase = object(bout.toJson()['mutual_hits'])['phase'];
      if (session.a.score == session.b.score ||
          (phase == 'SUDDEN_DEATH' &&
              !((session.a.score == 1 && session.b.score == 0) ||
                  (session.a.score == 0 && session.b.score == 1)))) {
        throw const FormatException('A decisive elimination score is required');
      }
    }
    return PendingSubmission.fromJson({
      'schema_version': 1,
      'origin': origin,
      'tournament_id': bout.tournamentId,
      'nomination_id': bout.nominationId,
      'bout_id': bout.id,
      'version': bout.version,
      'fighter_a_id': session.a.id,
      'fighter_b_id': session.b.id,
      'score_a': session.a.score,
      'score_b': session.b.score,
      'idempotency_key': ids(),
      'client_event_id': ids(),
      'device_id': deviceId,
      'submitted_at': (now ?? DateTime.now)().toUtc().toIso8601String(),
    });
  }
  final String origin,
      tournamentId,
      nominationId,
      boutId,
      fighterAId,
      fighterBId;
  final String idempotencyKey, clientEventId, deviceId, submittedAt;
  final int version, scoreA, scoreB;
  final Json? judgeEvent;
  final String? judgingRevision, judgingPolicy;
  bool get isJudge => judgeEvent != null;
  Json get body => {
    if (isJudge) ...{
      'event': judgeEvent,
      'expected_judging_revision': judgingRevision,
    } else ...{
      'score_a': scoreA,
      'score_b': scoreB,
      'result_type': 'NORMAL',
    },
    'expected_pairing': {
      'fighter_a_id': fighterAId,
      'fighter_b_id': fighterBId,
    },
    'client_event_id': clientEventId,
    'device_id': deviceId,
    'submitted_at': submittedAt,
  };
  Json toJson() => {
    'schema_version': 1,
    'origin': origin,
    'tournament_id': tournamentId,
    'nomination_id': nominationId,
    'bout_id': boutId,
    'version': version,
    'fighter_a_id': fighterAId,
    'fighter_b_id': fighterBId,
    'score_a': scoreA,
    'score_b': scoreB,
    'idempotency_key': idempotencyKey,
    'client_event_id': clientEventId,
    'device_id': deviceId,
    'submitted_at': submittedAt,
    if (isJudge) ...{
      'judge_event': judgeEvent,
      'judging_revision': judgingRevision,
      'judging_policy': judgingPolicy,
    },
  };
}

abstract class PendingSubmissionRepository {
  bool get durable;
  Future<void> save(PendingSubmission submission);
  Future<PendingSubmission?> find(String clientEventId);
  Future<void> setState(String clientEventId, SubmissionState state);
}

/// Explicit first online slice: survives retries, NOT process death/restart.
class MemoryPendingSubmissionRepository implements PendingSubmissionRepository {
  final Map<String, PendingSubmission> _requests = {};
  final Map<String, SubmissionState> states = {};
  @override
  bool get durable => false;
  @override
  Future<PendingSubmission?> find(String clientEventId) async =>
      _requests[clientEventId];
  @override
  Future<void> save(PendingSubmission submission) async {
    final existing = _requests[submission.clientEventId];
    if (existing != null &&
        existing.toJson().toString() != submission.toJson().toString()) {
      throw StateError('Immutable submission');
    }
    _requests[submission.clientEventId] = submission;
  }

  @override
  Future<void> setState(String clientEventId, SubmissionState state) async =>
      states[clientEventId] = state;
}
