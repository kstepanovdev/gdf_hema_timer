import 'dart:convert';
import '../fight_log/fight_event.dart';
import 'models.dart';

// Historical Flutter names are deliberately NOT mapped by their English spelling.
enum JudgeEventKind { remark, warning, mutualHit }

String judgeEventName(JudgeEventKind kind) => switch (kind) {
  JudgeEventKind.remark => 'REMARK',
  JudgeEventKind.warning => 'WARNING',
  JudgeEventKind.mutualHit => 'MUTUAL_HIT',
};
JudgeEventKind judgeKindForPenalty(PenaltyKind kind) => switch (kind) {
  PenaltyKind.warning => JudgeEventKind.remark, // Зауваження
  PenaltyKind.caution => JudgeEventKind.warning, // Попередження
};

class JudgeAvailability {
  JudgeAvailability.fromJson(Json j)
    : available = j['available'] == true,
      reason = j['reason'] as String?;
  final bool available;
  final String? reason;
}

class JudgedFighter {
  JudgedFighter.fromJson(Json j)
    : id = uuid(j['fighter_id']),
      remarks = integer(j['effective_remarks']),
      warnings = integer(j['total_warnings']),
      disqualified = j['disqualified'] == true,
      remark = JudgeAvailability.fromJson(object(j['remark'])),
      warning = JudgeAvailability.fromJson(object(j['warning'])) {
    integer(j['direct_warnings']);
    integer(j['derived_warnings']);
    integer(j['remaining_remarks']);
  }
  final String id;
  final int remarks, warnings;
  final bool disqualified;
  final JudgeAvailability remark, warning;
}

class JudgingState {
  JudgingState.fromJson(Json j)
    : _json = object(jsonDecode(jsonEncode(j))),
      bout = TimerBout.fromJson(object(j['bout'])),
      revision = text(j['judging_revision']),
      remarksPerWarning = integer(
        object(j['discipline_policy'])['remarks_per_warning'],
      ),
      warningsForDisqualification = integer(
        object(j['discipline_policy'])['warnings_for_disqualification'],
      ),
      fighters = List.unmodifiable(
        array(j['fighters']).map((f) => JudgedFighter.fromJson(object(f))),
      ),
      records = List.unmodifiable(array(j['records']).map((r) => object(r))),
      mutualHit = JudgeAvailability.fromJson(object(j['mutual_hit'])),
      judgeWrite = object(j['permissions'])['judge_write'] == true,
      scoreSnapshotWrite =
          object(j['permissions'])['score_snapshot_write'] == true {
    if (j['schema_version'] != 1 ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(revision) ||
        remarksPerWarning < 1 ||
        warningsForDisqualification < 1 ||
        fighters.length != [bout.a, bout.b].where((f) => f != null).length ||
        fighters.map((f) => f.id).toSet().length != fighters.length ||
        fighters.any((f) => f.id != bout.a?.id && f.id != bout.b?.id)) {
      throw const FormatException('judging state');
    }
    final hits = object(object(j['bout'])['mutual_hits']);
    integer(hits['effective_count']);
    integer(hits['attempt']);
    if (!['STANDARD', 'REFIGHT', 'SUDDEN_DEATH'].contains(hits['phase'])) {
      throw const FormatException('unsupported judging phase');
    }
    final policy = object(hits['policy']);
    if (integer(policy['threshold']) < 1) {
      throw const FormatException('threshold');
    }
    if (![
      'DOUBLE_LOSS',
      'DISABLED',
      'REFIGHT_UNTIL_DECISIVE',
      'SUDDEN_DEATH',
      'REFIGHTS_THEN_SUDDEN_DEATH',
    ].contains(policy['action'])) {
      throw const FormatException('unsupported mutual-hit policy');
    }
    if (policy['action'] == 'REFIGHTS_THEN_SUDDEN_DEATH') {
      integer(policy['max_refights']);
    }
    for (final r in records) {
      uuid(r['record_id']);
      if (!['REMARK', 'WARNING', 'MUTUAL_HIT'].contains(r['type'])) {
        throw const FormatException('record type');
      }
      if (r['participant_id'] != null) uuid(r['participant_id']);
      if (r['bout_id'] != null) uuid(r['bout_id']);
      if (r['stage_id'] != null) uuid(r['stage_id']);
      integer(r['entity_version']);
      DateTime.parse(text(r['issued_at']));
      if (r['voided_at'] != null) DateTime.parse(text(r['voided_at']));
    }
  }
  final Json _json;
  final TimerBout bout;
  final String revision;
  final int remarksPerWarning, warningsForDisqualification;
  final List<JudgedFighter> fighters;
  final List<Json> records;
  final JudgeAvailability mutualHit;
  final bool judgeWrite, scoreSnapshotWrite;
  JudgedFighter fighter(String id) => fighters.singleWhere((f) => f.id == id);
  Json toJson() => object(jsonDecode(jsonEncode(_json)));
  Json get hitState => object(object(_json['bout'])['mutual_hits']);
  Json get policy => object(hitState['policy']);
  String get phase => text(hitState['phase']);
  int get attempt => integer(hitState['attempt']);
  String get policyKey => jsonEncode([_json['discipline_policy'], policy]);
  JudgeAvailability availability(JudgeEventKind kind, String? fighterId) =>
      switch (kind) {
        JudgeEventKind.remark => fighter(fighterId!).remark,
        JudgeEventKind.warning => fighter(fighterId!).warning,
        JudgeEventKind.mutualHit => mutualHit,
      };
}

class JudgingReceipt {
  JudgingReceipt.fromJson(Json j)
    : recordId = uuid(j['record_id']),
      eventId = uuid(j['client_event_id']),
      state = JudgingState.fromJson(object(j['judging'])),
      _json = object(jsonDecode(jsonEncode(j))) {
    if (j['schema_version'] != 1 ||
        j['source'] != 'timer' ||
        !state.records.any((r) => r['record_id'] == recordId)) {
      throw const FormatException('judging receipt');
    }
    DateTime.parse(text(j['accepted_at']));
  }
  final String recordId, eventId;
  final JudgingState state;
  final Json _json;
  Json toJson() => object(jsonDecode(jsonEncode(_json)));
}
