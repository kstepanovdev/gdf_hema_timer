import 'dart:convert';
import '../bout_session/bout_session.dart';

/// The consumed subset of Timer API v1. Unknown additive fields are ignored;
/// missing readiness information always fails closed.
typedef Json = Map<String, dynamic>;
Json object(Object? value) {
  if (value is! Map<String, dynamic>) throw const FormatException('object');
  return value;
}

List<dynamic> array(Object? value) {
  if (value is! List) throw const FormatException('array');
  return value;
}

String text(Object? value) {
  if (value is! String || value.isEmpty) throw const FormatException('text');
  return value;
}

String uuid(Object? value) {
  final id = text(value);
  if (!RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  ).hasMatch(id)) {
    throw const FormatException('uuid');
  }
  return id;
}

int integer(Object? value) {
  if (value is! int || value < 0 || value > 9007199254740991) {
    throw const FormatException('integer');
  }
  return value;
}

String revision(Object? value) {
  final result = text(value);
  if (!RegExp(r'^\d+$').hasMatch(result)) {
    throw const FormatException('revision');
  }
  return result;
}

class NominationRef {
  Json toJson() => {
    'tournament_id': tournamentId,
    'event_name': tournamentName,
    'nomination_id': id,
    'name': name,
    'status': 'ACTIVE',
    'tournament_revision': '0',
  };
  NominationRef.fromJson(Json json)
    : tournamentId = uuid(json['tournament_id']),
      tournamentName = text(json['event_name']),
      id = uuid(json['nomination_id']),
      name = text(json['name']) {
    if (json['status'] != 'ACTIVE') {
      throw const FormatException('active nomination');
    }
    revision(json['tournament_revision']);
  }
  final String tournamentId, tournamentName, id, name;
}

class TimerFighter {
  TimerFighter.fromJson(Json json)
    : id = uuid(json['fighter_id']),
      name = text(json['display_name']);
  final String id, name;
}

class TimerBout {
  TimerBout.fromJson(Json json)
    : _json = object(jsonDecode(jsonEncode(json))),
      id = uuid(json['bout_id']),
      tournamentId = uuid(json['tournament_id']),
      nominationId = uuid(json['nomination_id']),
      stageId = uuid(json['stage_id']),
      stageName = text(json['stage_name']),
      stageType = text(json['stage_type']),
      stageStatus = text(json['stage_status']),
      groupId = json['group_id'] == null ? null : uuid(json['group_id']),
      groupName = json['group_name'] as String?,
      pisteId = json['piste_id'] == null ? null : uuid(json['piste_id']),
      pisteName = json['piste_name'] as String?,
      configurationId = json['configuration_id'] == null
          ? null
          : uuid(json['configuration_id']),
      configurationSequence = json['configuration_sequence'] == null
          ? null
          : integer(json['configuration_sequence']),
      executionStep = json['execution_step'] == null
          ? null
          : integer(json['execution_step']),
      sequence = integer(json['sequence']),
      version = integer(json['entity_version']),
      serverRevision = revision(json['tournament_revision']),
      a = json['fighter_a'] == null
          ? null
          : TimerFighter.fromJson(object(json['fighter_a'])),
      b = json['fighter_b'] == null
          ? null
          : TimerFighter.fromJson(object(json['fighter_b'])),
      status = text(json['status']),
      purpose = text(json['purpose']),
      scoreA = json['score_a'] == null ? null : integer(json['score_a']),
      scoreB = json['score_b'] == null ? null : integer(json['score_b']),
      resultType = json['result_type'] as String?,
      available =
          json['availability'] is Map &&
          object(json['availability'])['available'] == true,
      blockingCode = json['availability'] is Map
          ? object(json['availability'])['reason'] as String?
          : 'BOUT_NOT_WRITABLE',
      effectiveHits = json['mutual_hits'] == null
          ? null
          : integer(object(json['mutual_hits'])['effective_count']);

  final Json _json;
  Json toJson() => object(jsonDecode(jsonEncode(_json)));
  final String id,
      tournamentId,
      nominationId,
      stageId,
      stageName,
      stageType,
      stageStatus;
  final String status, purpose, serverRevision;
  final String? groupId,
      groupName,
      pisteId,
      pisteName,
      configurationId,
      blockingCode,
      resultType;
  final int sequence, version;
  final int? configurationSequence,
      executionStep,
      scoreA,
      scoreB,
      effectiveHits;
  final TimerFighter? a, b;
  final bool available;
  bool get supported =>
      (purpose == 'REGULAR' ||
          (purpose == 'TIE_BREAK' && tieBreakRoundId != null)) &&
      (stageType == 'SINGLE_ROUND_ROBIN' ||
          stageType == 'MULTI_ROUND_ROBIN' ||
          stageType == 'SINGLE_ELIMINATION');
  bool get writable =>
      supported &&
      available &&
      status == 'SCHEDULED' &&
      (stageStatus == 'IN_PROGRESS' ||
          (purpose == 'TIE_BREAK' && stageStatus == 'COMPLETED')) &&
      a != null &&
      b != null &&
      a!.id != b!.id &&
      effectiveHits != null;
  BoutSession toSession() => BoutSession(
    id: id,
    a: BoutFighter(id: a!.id, name: a!.name, score: scoreA ?? 0),
    b: BoutFighter(id: b!.id, name: b!.name, score: scoreB ?? 0),
    mutualHits: effectiveHits ?? 0,
  );
  TimerFighter? get automaticWinner {
    final id = _json['auto_win_winner_id'];
    return id == a?.id
        ? a
        : id == b?.id
        ? b
        : null;
  }

  String? get bracketRole => _json['bracket_role'] as String?;
  int? get bracketRound => _json['bracket_round'] as int?;
  String? get tieBreakRoundId => _json['tie_break_round'] == null
      ? null
      : uuid(object(_json['tie_break_round'])['tie_break_round_id']);
  int? get tieBreakSequence => _json['tie_break_round'] == null
      ? null
      : integer(object(_json['tie_break_round'])['sequence']);
  bool get operational =>
      stageType == 'SINGLE_ELIMINATION' || purpose == 'TIE_BREAK';
  String get context => [stageName, ?groupName, ?pisteName].join(' · ');
}

class WorkStage {
  WorkStage.fromJson(Json j)
    : id = uuid(j['stage_id']),
      name = text(j['name']),
      type = text(j['type']),
      status = text(j['status']),
      order = integer(j['order']);
  final String id, name, type, status;
  final int order;
}

class WorkWave {
  WorkWave.fromJson(Json j)
    : id = uuid(j['wave_id']),
      stageId = uuid(j['stage_id']),
      name = text(j['name']),
      order = integer(j['order']);
  final String id, stageId, name;
  final int order;
}

class WorkGroup {
  WorkGroup.fromJson(Json j)
    : id = uuid(j['group_id']),
      stageId = uuid(j['stage_id']),
      name = text(j['name']),
      status = text(j['schedule_status']),
      progress = j['progress'] as String?,
      blockingCode = j['blocking_code'] as String?,
      remainingBouts = j['remaining_bouts'] == null
          ? null
          : integer(j['remaining_bouts']),
      order = integer(j['order']);
  final String id, stageId, name, status;
  final String? progress, blockingCode;
  final int? remainingBouts;
  final int order;
}

class WorkAllocation {
  WorkAllocation.fromJson(Json j)
    : groupId = uuid(j['group_id']),
      stageId = uuid(j['stage_id']),
      waveId = uuid(j['wave_id']),
      pisteIds = List.unmodifiable(array(j['piste_ids']).map(uuid));
  final String groupId, stageId, waveId;
  final List<String> pisteIds;
}

class WorkConfiguration {
  WorkConfiguration.fromJson(Json j)
    : id = uuid(j['configuration_id']),
      groupId = uuid(j['group_id']),
      sequence = integer(j['sequence']),
      status = text(j['status']),
      firstStep = integer(j['first_execution_step']),
      lastStep = integer(j['last_execution_step']),
      populations = Map.unmodifiable({
        for (final a in array(j['assignments']).map(object))
          uuid(a['piste_id']): List<String>.unmodifiable(
            array(a['fighter_ids']).map(uuid),
          ),
      });
  final String id, groupId, status;
  final int sequence, firstStep, lastStep;
  final Map<String, List<String>> populations;
}

class WorkMovement {
  WorkMovement.fromJson(Json j)
    : fighter = TimerFighter.fromJson(object(j['participant'])),
      fromPisteId = uuid(j['from_piste_id']),
      toPisteId = uuid(j['to_piste_id']);
  final TimerFighter fighter;
  final String fromPisteId, toPisteId;
}

class WorkAssignment {
  WorkAssignment.fromJson(Json j, this.pisteId, this.pisteName)
    : stage = WorkStage.fromJson(object(j['stage'])),
      group = WorkGroup.fromJson(object(j['group'])),
      wave = j['wave'] == null ? null : WorkWave.fromJson(object(j['wave'])),
      configurationId = j['configuration'] == null
          ? null
          : uuid(object(j['configuration'])['configuration_id']),
      configurationSequence = j['configuration'] == null
          ? null
          : integer(object(j['configuration'])['sequence']),
      configurationCount = j['configuration'] == null
          ? null
          : integer(object(j['configuration'])['count']),
      configurationStatus = j['configuration'] == null
          ? null
          : text(object(j['configuration'])['status']),
      fightersHere = List.unmodifiable(
        array(j['fighters_here']).map((e) => TimerFighter.fromJson(object(e))),
      ),
      nextPopulation = j['next_population_here'] == null
          ? null
          : List.unmodifiable(
              array(
                j['next_population_here'],
              ).map((e) => TimerFighter.fromJson(object(e))),
            ),
      movesAfter = List.unmodifiable(
        array(j['moves_after']).map((e) => WorkMovement.fromJson(object(e))),
      ),
      remainingHere = integer(j['remaining_here']),
      remainingElsewhere = integer(j['remaining_elsewhere']),
      items = List.unmodifiable(
        array(j['items']).map((e) => WorkItem.fromJson(object(e))),
      ) {
    if (j['kind'] != 'ROUND_ROBIN_CONFIGURATION' ||
        group.stageId != stage.id ||
        (wave != null && wave!.stageId != stage.id)) {
      throw const FormatException('segment scope');
    }
  }
  final String pisteId, pisteName;
  final WorkStage stage;
  final WorkGroup group;
  final WorkWave? wave;
  String get stageId => stage.id;
  String get stageName => stage.name;
  String get groupId => group.id;
  String get groupName => group.name;
  final String? configurationId, configurationStatus;
  final int? configurationSequence, configurationCount;
  final int remainingHere, remainingElsewhere;
  final List<TimerFighter> fightersHere;
  final List<TimerFighter>? nextPopulation;
  final List<WorkMovement> movesAfter;
  final List<WorkItem> items;
  String get label => '$stageName · $groupName · $pisteName';
}

class WorkItem {
  WorkItem.fromJson(Json json)
    : bout = TimerBout.fromJson(object(json['bout'])),
      readiness = text(json['readiness']),
      orderKey = List.unmodifiable(
        array(json['order_key']).map((e) => e == null ? null : integer(e)),
      );
  final TimerBout bout;
  final String readiness;
  final List<int?> orderKey;
  bool get selectable => readiness == 'READY' && bout.writable;
}

class PisteWorklist {
  PisteWorklist.fromJson(Json j)
    : id = uuid(object(j['piste'])['piste_id']),
      name = text(object(j['piste'])['name']),
      recommendedBoutId = j['recommended_bout_id'] == null
          ? null
          : uuid(j['recommended_bout_id']),
      groups = List.unmodifiable(
        array(j['groups']).map((e) => WorkGroup.fromJson(object(e))),
      ),
      recent = List.unmodifiable(
        array(j['completed_recent']).map((e) => WorkItem.fromJson(object(e))),
      ) {
    assignments = List.unmodifiable(
      array(
        j['segments'],
      ).map((e) => WorkAssignment.fromJson(object(e), id, name)),
    );
  }
  final String id, name;
  final String? recommendedBoutId;
  final List<WorkGroup> groups;
  final List<WorkItem> recent;
  late final List<WorkAssignment> assignments;
  WorkItem? get recommended {
    for (final a in assignments) {
      for (final i in a.items) {
        if (i.bout.id == recommendedBoutId && i.selectable) return i;
      }
    }
    return null;
  }
}

class TimerWorklist {
  TimerWorklist.fromJson(Json j)
    : _json = object(jsonDecode(jsonEncode(j))),
      tournamentId = uuid(j['tournament_id']),
      nominationId = uuid(j['nomination_id']),
      serverRevision = revision(j['tournament_revision']),
      stages = List.unmodifiable(
        array(j['stages']).map((e) => WorkStage.fromJson(object(e))),
      ),
      waves = List.unmodifiable(
        array(j['execution_waves']).map((e) => WorkWave.fromJson(object(e))),
      ),
      groups = List.unmodifiable(
        array(j['groups']).map((e) => WorkGroup.fromJson(object(e))),
      ),
      allocations = List.unmodifiable(
        array(
          j['group_allocations'],
        ).map((e) => WorkAllocation.fromJson(object(e))),
      ),
      configurations = List.unmodifiable(
        array(
          j['configurations'],
        ).map((e) => WorkConfiguration.fromJson(object(e))),
      ),
      operational = List.unmodifiable(
        array(
          j['operational_bouts'] ?? j['unassigned'] ?? <dynamic>[],
        ).map((e) => WorkItem.fromJson(object(e))),
      ),
      pistes = List.unmodifiable(
        array(
          j['piste_worklists'],
        ).map((e) => PisteWorklist.fromJson(object(e))),
      ) {
    if (j['schema_version'] != 1) {
      throw const FormatException('worklist version');
    }
    final stageIds = stages.map((s) => s.id).toSet(),
        groupIds = groups.map((g) => g.id).toSet(),
        pisteIds = pistes.map((p) => p.id).toSet();
    if (stageIds.length != stages.length ||
        groupIds.length != groups.length ||
        pisteIds.length != pistes.length) {
      throw const FormatException('duplicate identity');
    }
    for (final g in groups) {
      if (!stageIds.contains(g.stageId)) {
        throw const FormatException('group stage');
      }
    }
    for (final w in waves) {
      if (!stageIds.contains(w.stageId)) {
        throw const FormatException('wave stage');
      }
    }
    for (final a in allocations) {
      if (!groups.any((g) => g.id == a.groupId && g.stageId == a.stageId) ||
          !waves.any((w) => w.id == a.waveId && w.stageId == a.stageId) ||
          !a.pisteIds.every(pisteIds.contains)) {
        throw const FormatException('allocation scope');
      }
    }
    for (final c in configurations) {
      if (!groupIds.contains(c.groupId) ||
          !c.populations.keys.every(pisteIds.contains)) {
        throw const FormatException('configuration scope');
      }
    }
    final operationalIds = <String>{};
    for (final item in operational) {
      final b = item.bout;
      if (!b.operational ||
          b.tournamentId != tournamentId ||
          b.nominationId != nominationId ||
          !stages.any(
            (s) =>
                s.id == b.stageId &&
                s.type == b.stageType &&
                s.status == b.stageStatus,
          ) ||
          (b.groupId != null &&
              !groups.any(
                (g) => g.id == b.groupId && g.stageId == b.stageId,
              )) ||
          (b.pisteId != null && !pisteIds.contains(b.pisteId)) ||
          !operationalIds.add(b.id)) {
        throw const FormatException('operational bout scope');
      }
    }
    final seen = <String>{};
    for (final raw in array(j['piste_worklists'])) {
      final p = object(raw);
      if (p['schema_version'] != 1 ||
          p['tournament_id'] != tournamentId ||
          p['nomination_id'] != nominationId ||
          revision(p['tournament_revision']) != serverRevision) {
        throw const FormatException('worklist scope');
      }
    }
    for (final p in pistes) {
      for (final a in p.assignments) {
        if (!stages.any(
              (s) => s.id == a.stageId && s.status == a.stage.status,
            ) ||
            !groups.any(
              (g) =>
                  g.id == a.groupId &&
                  g.stageId == a.stageId &&
                  g.status == a.group.status,
            )) {
          throw const FormatException('segment hierarchy');
        }
        if (a.configurationId != null &&
            !configurations.any(
              (c) =>
                  c.id == a.configurationId &&
                  c.groupId == a.groupId &&
                  c.sequence == a.configurationSequence &&
                  c.status == a.configurationStatus,
            )) {
          throw const FormatException('segment configuration');
        }
        for (final i in a.items) {
          final b = i.bout;
          if (b.tournamentId != tournamentId ||
              b.nominationId != nominationId ||
              b.stageId != a.stageId ||
              b.groupId != a.groupId ||
              b.pisteId != p.id ||
              b.configurationId != a.configurationId ||
              !seen.add(b.id)) {
            throw const FormatException('bout scope');
          }
          if (i.selectable &&
              (a.group.status != 'STARTED' ||
                  (a.configurationStatus != null &&
                      a.configurationStatus != 'ACTIVE'))) {
            throw const FormatException('future writable');
          }
        }
      }
    }
  }
  final Json _json;
  Json toJson() => object(jsonDecode(jsonEncode(_json)));
  final String tournamentId, nominationId, serverRevision;
  final List<WorkStage> stages;
  final List<WorkWave> waves;
  final List<WorkGroup> groups;
  final List<WorkAllocation> allocations;
  final List<WorkConfiguration> configurations;
  final List<PisteWorklist> pistes;
  final List<WorkItem> operational;
  List<WorkAssignment> get assignments =>
      List.unmodifiable(pistes.expand((p) => p.assignments));
  PisteWorklist? piste(String? id) {
    for (final p in pistes) {
      if (p.id == id) return p;
    }
    return null;
  }

  TimerBout? bout(String id) {
    for (final item in operational) {
      if (item.bout.id == id) return item.bout;
    }
    for (final p in pistes) {
      for (final i in [...p.assignments.expand((a) => a.items), ...p.recent]) {
        if (i.bout.id == id) return i.bout;
      }
    }
    return null;
  }

  String pisteName(String id) => piste(id)?.name ?? '—';
  String fighterName(String id) {
    for (final a in assignments) {
      for (final f in [
        ...a.fightersHere,
        ...?a.nextPopulation,
        ...a.movesAfter.map((m) => m.fighter),
      ]) {
        if (f.id == id) return f.name;
      }
    }
    return '—';
  }
}

class AcceptedResult {
  Json toJson() => {
    'bout_id': boutId,
    'entity_version': version,
    'tournament_revision': serverRevision,
    'score_a': scoreA,
    'score_b': scoreB,
    'result_type': resultType,
    'accepted_at': acceptedAt.toUtc().toIso8601String(),
    'status': 'COMPLETED',
    'source': 'timer',
    'replayed': replayed,
  };
  AcceptedResult.fromJson(Json json, {this.replayed})
    : boutId = uuid(json['bout_id']),
      version = integer(json['entity_version']),
      serverRevision = revision(json['tournament_revision']),
      scoreA = integer(json['score_a']),
      scoreB = integer(json['score_b']),
      resultType = text(json['result_type']),
      acceptedAt = DateTime.parse(text(json['accepted_at'])) {
    if (json['status'] != 'COMPLETED' || json['source'] != 'timer') {
      throw const FormatException('receipt');
    }
  }
  final String boutId, serverRevision, resultType;
  final int version, scoreA, scoreB;
  final DateTime acceptedAt;
  final bool? replayed;
}
