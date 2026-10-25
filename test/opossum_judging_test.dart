import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:gdf_hema_timer/modules/bout_session/bout_session.dart';
import 'package:gdf_hema_timer/modules/bout_session/bout_session_controller.dart';
import 'package:gdf_hema_timer/modules/fight_log/fight_event.dart';
import 'package:gdf_hema_timer/modules/opossum/api_client.dart';
import 'package:gdf_hema_timer/modules/opossum/cached_client.dart';
import 'package:gdf_hema_timer/modules/opossum/judging.dart';
import 'package:gdf_hema_timer/modules/opossum/judging_controller.dart';
import 'package:gdf_hema_timer/modules/opossum/models.dart';
import 'package:gdf_hema_timer/modules/opossum/outbox_sync.dart';
import 'package:gdf_hema_timer/modules/opossum/pending_submission.dart';
import 'package:gdf_hema_timer/modules/opossum/session_recorder.dart';
import 'package:gdf_hema_timer/modules/opossum/session_snapshot.dart';
import 'package:gdf_hema_timer/modules/opossum/tournament_store.dart';
import 'support/opossum_fixture.dart';
import 'support/judging_fixture.dart';

void main() {
  sqfliteFfiInit();
  late Directory dir;
  late TournamentStore store;
  late FakeJudgingServer server;
  late HttpOpossumClient api;
  final credential = credentialFingerprint(syntheticToken);
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('timer-judge-');
    store = await TournamentStore.open(
      databaseFactoryFfi,
      '${dir.path}/test.sqlite',
    );
    server = FakeJudgingServer();
    api = HttpOpossumClient(
      ConnectionConfig('https://example.test', syntheticToken),
      client: server.client(),
      timeout: const Duration(milliseconds: 40),
      readRetries: 0,
    );
  });
  tearDown(() async {
    api.close();
    await store.close();
    await dir.delete(recursive: true);
  });
  SessionSnapshot snapshot({JudgingState? judging}) {
    final bout = (judging ?? JudgingState.fromJson(server.judging)).bout;
    final n = NominationRef.fromJson(
      object(array(object(server.data['discovery'])['nominations']).first),
    );
    final session = bout.toSession();
    return SessionSnapshot(
      origin: 'https://example.test',
      nomination: n,
      bout: bout,
      session: session.copyWith(
        a: session.a.copyWith(score: 7),
        b: session.b.copyWith(score: 4),
      ),
      remainingMs: 45000,
      configuredMs: 90000,
      wasRunning: false,
      events: [],
      savedAt: DateTime.now(),
    );
  }

  Future<PendingSubmission> queue({
    JudgeEventKind kind = JudgeEventKind.mutualHit,
    String? fighterId,
    JudgingState? state,
  }) async {
    final current = state ?? JudgingState.fromJson(server.judging),
        saved = snapshot(judging: current);
    final request = PendingSubmission.judge(
      origin: saved.origin,
      judging: current,
      session: saved.session,
      kind: kind,
      fighterId: fighterId,
      deviceId: deviceId,
    );
    await store.confirmJudge(request, saved, credential);
    return request;
  }

  OutboxSync worker() => OutboxSync(
    store: store,
    api: api,
    origin: 'https://example.test',
    credentialRef: credential,
  );
  Future<
    ({
      BoutSessionController session,
      SessionRecorder recorder,
      JudgingController judging,
    })
  >
  coordinator([String scenario = 'rr']) async {
    if (scenario != 'rr') {
      api.close();
      server = FakeJudgingServer(scenario);
      api = HttpOpossumClient(
        ConnectionConfig('https://example.test', syntheticToken),
        client: server.client(),
        readRetries: 0,
      );
    }
    final saved = snapshot();
    final session = BoutSessionController(initialSession: saved.session);
    final recorder = SessionRecorder(
      store: store,
      controller: session,
      origin: saved.origin,
      nomination: saved.nomination,
      bout: saved.bout,
      configuredMs: 90000,
    )..checkpoint();
    await recorder.flush();
    final judging = JudgingController(
      api: api,
      session: session,
      initialBout: saved.bout,
      origin: saved.origin,
      deviceId: deviceId,
      store: store,
      recorder: recorder,
      credentialRef: credential,
      snapshot: recorder.snapshot,
    );
    addTearDown(() async {
      judging.dispose();
      await recorder.flush();
      recorder.dispose();
      session.dispose();
    });
    await judging.start();
    return (session: session, recorder: recorder, judging: judging);
  }

  test(
    'standalone counters and explicit historical enum mapping stay distinct',
    () {
      final c = BoutSessionController();
      addTearDown(c.dispose);
      c.setPenalty(DisplaySide.left, PenaltyKind.warning, 2);
      c.setPenalty(DisplaySide.right, PenaltyKind.caution, 1);
      c.setMutualHits(3);
      expect(c.session.a.warning, 2);
      expect(c.session.b.caution, 1);
      expect(judgeKindForPenalty(PenaltyKind.warning), JudgeEventKind.remark);
      expect(judgeKindForPenalty(PenaltyKind.caution), JudgeEventKind.warning);
      expect(c.fightLog.events.whereType<PenaltyChanged>(), hasLength(2));
    },
  );
  test(
    'all authoritative contract fixtures decode without deriving sporting counts in Dart',
    () {
      for (final name in ['rr', 'discipline', 'elimination']) {
        final sequence = object(judgingFixture()[name]);
        JudgingState.fromJson(object(sequence['initial']));
        for (final raw in array(sequence['operations'])) {
          final state = JudgingState.fromJson(object(object(raw)['judging']));
          expect(state.fighters, hasLength(2));
        }
      }
    },
  );
  test(
    'read authenticates and derives nothing locally; bad/expired credentials fail closed',
    () async {
      final state = await api.judging(text(server.current['bout_id']));
      expect(state.fighters.first.remarks, 0);
      server.denyJudgingRead = 401;
      await expectLater(
        api.judging(state.bout.id),
        throwsA(
          isA<OpossumException>().having(
            (e) => e.kind,
            'kind',
            ApiFailure.authentication,
          ),
        ),
      );
    },
  );
  test(
    'durable event and original preconditions survive close/reopen; payload has only approved fields',
    () async {
      final r = await queue();
      expect(
        r.body.keys,
        unorderedEquals([
          'expected_pairing',
          'expected_judging_revision',
          'event',
          'client_event_id',
          'device_id',
          'submitted_at',
        ]),
      );
      await store.close();
      store = await TournamentStore.open(
        databaseFactoryFfi,
        '${dir.path}/test.sqlite',
      );
      expect(
        (await store.entry(r.clientEventId))!.request.toJson(),
        r.toJson(),
      );
      final w = worker();
      await w.flush();
      await w.shutdown();
      expect(
        (await store.entry(r.clientEventId))!.state,
        OutboxState.acknowledged,
      );
      expect(await store.hasResult(r.origin, r.boutId), isFalse);
    },
  );
  test(
    'three dependent offline hits use predecessor receipts and derive only the server Double Loss',
    () async {
      final basis = JudgingState.fromJson(server.judging);
      final requests = [
        await queue(state: basis),
        await queue(state: basis),
        await queue(state: basis),
      ];
      expect((await store.entries()).last.dependencies, [
        requests[1].clientEventId,
      ]);
      expect(server.judgeMutations, 0);
      final w = worker();
      await w.flush();
      await w.shutdown();
      final entries = await store.entries();
      expect(entries.every((e) => e.state == OutboxState.acknowledged), isTrue);
      expect(entries[1].intent.version, basis.bout.version);
      expect(entries[1].request.version, greaterThan(basis.bout.version));
      expect(server.judgeMutations, 3);
      expect(server.current['result_type'], 'DOUBLE_LOSS');
      expect(server.writes.every((r) => r.method == 'POST'), isTrue);
      final cached = await store.cached(
        'judging|${requests[0].origin}|${basis.bout.id}',
      );
      expect(JudgingState.fromJson(cached!.body).bout.effectiveHits, 3);
    },
  );
  test(
    'lost accepted receipt survives restart and replays exactly the prepared request',
    () async {
      server.loseJudgeReceipt = true;
      final r = await queue();
      final w = worker();
      await w.flush();
      await w.shutdown();
      expect(server.judgeMutations, 1);
      final prepared = (await store.entry(r.clientEventId))!.request.toJson();
      await store.close();
      store = await TournamentStore.open(
        databaseFactoryFfi,
        '${dir.path}/test.sqlite',
      );
      await store.retryTransport(r.origin);
      final resumed = worker();
      await resumed.flush();
      await resumed.shutdown();
      expect(
        (await store.entry(r.clientEventId))!.state,
        OutboxState.acknowledged,
      );
      expect((await store.entry(r.clientEventId))!.request.toJson(), prepared);
      expect(server.judgeMutations, 1);
      expect(server.writes.map((r) => r.headers['idempotency-key']).toSet(), {
        r.idempotencyKey,
      });
    },
  );
  test(
    'a rejected event retains evidence and blocks dependent events, never replacing a version',
    () async {
      final first = await queue();
      final second = await queue();
      server.denyJudge = 422;
      final w = worker();
      await w.flush();
      await w.shutdown();
      expect(
        (await store.entry(first.clientEventId))!.state,
        OutboxState.rejected,
      );
      expect((await store.entry(second.clientEventId))!.attempts, 0);
      expect(server.judgeMutations, 0);
    },
  );
  test(
    'a changed pairing conflicts before sending; dependent events stay pending',
    () async {
      final first = await queue(), second = await queue();
      final replacement = '00000000-0000-4000-8000-00000000aaaa';
      object(server.current['fighter_a'])['fighter_id'] = replacement;
      server.judging['bout'] = clone(server.current);
      object(array(server.judging['fighters']).first)['fighter_id'] =
          replacement;
      final w = worker();
      await w.flush();
      await w.shutdown();
      expect(
        (await store.entry(first.clientEventId))!.state,
        OutboxState.conflict,
      );
      expect((await store.entry(second.clientEventId))!.attempts, 0);
      expect(server.writes, isEmpty);
    },
  );
  test('two concurrent sync workers issue an event only once', () async {
    await queue();
    final one = worker(), two = worker();
    await Future.wait([one.flush(), two.flush()]);
    await one.shutdown();
    await two.shutdown();
    expect(server.judgeMutations, 1);
    expect(server.writes, hasLength(1));
  });
  test(
    'an unsent last action can be cancelled without pretending to undo accepted history',
    () async {
      final r = await queue();
      await store.cancelUnsentJudge(r.clientEventId);
      expect(
        (await store.entry(r.clientEventId))!.state,
        OutboxState.cancelled,
      );
      final w = worker();
      await w.flush();
      await w.shutdown();
      expect(server.writes, isEmpty);
      final accepted = await queue();
      final next = worker();
      await next.flush();
      await next.shutdown();
      await expectLater(
        store.cancelUnsentJudge(accepted.clientEventId),
        throwsStateError,
      );
      expect(server.judgeMutations, 1);
    },
  );
  test('cancellation cannot strand an approved dependent action', () async {
    final first = await queue();
    await queue();
    await expectLater(
      store.cancelUnsentJudge(first.clientEventId),
      throwsStateError,
    );
  });
  test(
    'missing judge scope and revoked credentials pause sending without losing the request',
    () async {
      final r = await queue();
      server.denyJudge = 403;
      final w = worker();
      await w.flush();
      await w.shutdown();
      expect(
        (await store.entry(r.clientEventId))!.state,
        OutboxState.authentication,
      );
      expect(
        (await store.entry(r.clientEventId))!.request.clientEventId,
        r.clientEventId,
      );
    },
  );
  test(
    'offline cached judging keeps pending events unofficial then synchronizes later',
    () async {
      final cached = CachedOpossumClient(
        network: api,
        store: store,
        origin: 'https://example.test',
      );
      final initial = await cached.judging(text(server.current['bout_id']));
      server.failReads = true;
      final offline = await cached.judging(initial.bout.id);
      expect(cached.offline, isTrue);
      final r = await queue(state: offline);
      final w = worker();
      await w.flush();
      expect((await store.entry(r.clientEventId))!.state, OutboxState.pending);
      expect(offline.bout.effectiveHits, 0);
      server.failReads = false;
      await w.retry();
      await w.shutdown();
      expect(
        (await store.entry(r.clientEventId))!.state,
        OutboxState.acknowledged,
      );
    },
  );
  test(
    'a score result cannot be queued while judge-event consequences remain uncertain',
    () async {
      await queue();
      final saved = snapshot();
      final r = PendingSubmission.confirm(
        origin: saved.origin,
        bout: saved.bout,
        session: saved.session,
        deviceId: deviceId,
      );
      await expectLater(store.confirm(r, saved, credential), throwsStateError);
      expect((await store.entries()).where((e) => !e.request.isJudge), isEmpty);
    },
  );
  test(
    'failed SQLite confirmation does not manufacture success or a partial local action',
    () async {
      await store.db.execute(
        "CREATE TRIGGER reject_judge BEFORE INSERT ON outbox BEGIN SELECT RAISE(ABORT, 'synthetic disk failure'); END",
      );
      await expectLater(queue(), throwsA(anything));
      expect(await store.entries(), isEmpty);
    },
  );
  test(
    'side swapping associates REMARK/WARNING with immutable fighters, not screen columns',
    () async {
      final c = await coordinator('discipline');
      c.session.swapSides();
      final a = c.session.at(DisplaySide.right).id,
          b = c.session.at(DisplaySide.left).id;
      await c.judging.confirm(
        judgeKindForPenalty(PenaltyKind.warning),
        fighterId: a,
      );
      await c.judging.confirm(
        judgeKindForPenalty(PenaltyKind.caution),
        fighterId: b,
      );
      expect(c.session.session.a.warning, 0);
      expect(c.session.session.b.caution, 0);
      final w = worker();
      await w.flush();
      await w.shutdown();
      await c.judging.refresh();
      expect(c.session.session.leftIsA, isFalse);
      expect(c.session.at(DisplaySide.right).warning, 1);
      expect(c.session.at(DisplaySide.left).caution, 1);
      expect(c.judging.pending, isEmpty);
      expect(c.session.fightLog.events.whereType<PenaltyChanged>(), isEmpty);
      final standalone = BoutSessionController();
      expect(standalone.session.a.warning, 0);
      standalone.dispose();
    },
  );
  test(
    'server counts include derived warnings and disqualification without local rule calculations',
    () async {
      final c = await coordinator('discipline');
      final expected = array(
        object(judgingFixture()['discipline'])['operations'],
      );
      for (final raw in expected) {
        final event = object(object(raw)['event']);
        await c.judging.confirm(
          event['type'] == 'REMARK'
              ? JudgeEventKind.remark
              : JudgeEventKind.warning,
          fighterId: event['participant_id'] as String,
        );
      }
      final w = worker();
      await w.flush();
      await w.shutdown();
      await c.judging.refresh();
      expect(c.judging.state!.fighter(c.session.session.a.id).remarks, 4);
      expect(c.judging.state!.fighter(c.session.session.a.id).warnings, 1);
      expect(
        c.judging.state!.fighter(c.session.session.b.id).disqualified,
        isTrue,
      );
      expect(c.session.session.b.caution, 3);
      expect(c.judging.canReview, isFalse);
    },
  );
  test(
    'authoritative threshold completion prevents a competing result confirmation',
    () async {
      final c = await coordinator();
      for (var i = 0; i < 3; i++) {
        await c.judging.confirm(JudgeEventKind.mutualHit);
      }
      expect(c.judging.canReview, isFalse);
      expect(c.session.session.mutualHits, 0);
      final w = worker();
      await w.flush();
      await w.shutdown();
      await c.judging.refresh();
      expect(c.judging.state!.bout.resultType, 'DOUBLE_LOSS');
      expect(c.session.session.mutualHits, 3);
      expect(c.judging.terminal, isTrue);
      expect(c.judging.canReview, isFalse);
      expect(c.judging.canIssue(JudgeEventKind.mutualHit, null), isFalse);
      expect(c.recorder.bout.version, c.judging.bout.version);
      expect(server.writes.where((r) => r.method == 'PUT'), isEmpty);
    },
  );
  test(
    'elimination continuation preserves the prior draft until explicit review and respects sudden-death scores',
    () async {
      final c = await coordinator('elimination');
      c.session.start();
      for (var i = 0; i < 9; i++) {
        await c.judging.confirm(JudgeEventKind.mutualHit);
      }
      expect(c.judging.state!.phase, 'STANDARD');
      final w = worker();
      await w.flush();
      await w.shutdown();
      await c.judging.refresh();
      expect(c.judging.state!.phase, 'SUDDEN_DEATH');
      expect(c.judging.state!.attempt, 3);
      expect(c.session.session.mutualHits, 9);
      expect(c.session.running, isFalse);
      expect(c.session.session.a.score, 7);
      expect(c.session.session.b.score, 4);
      expect(c.judging.continuationReview, isTrue);
      expect(c.judging.canReview, isFalse);
      c.judging.acceptContinuation();
      expect(c.session.session.a.score, 0);
      expect(c.session.session.b.score, 0);
      expect(c.judging.canReview, isFalse);
      c.session.setScore(DisplaySide.left, 2);
      expect(c.judging.canReview, isFalse);
      c.session.setScore(DisplaySide.left, 1);
      expect(c.judging.canReview, isTrue);
      expect(
        PendingSubmission.confirm(
          origin: c.judging.origin,
          bout: c.judging.bout,
          session: c.session.session,
          deviceId: deviceId,
        ).body['score_a'],
        1,
      );
      expect(c.judging.bout.resultType, isNull);
    },
  );
  test(
    'known missing/expired judge scope disables event controls and preserves an active draft',
    () async {
      final c = await coordinator();
      object(server.judging['permissions'])['judge_write'] = false;
      await c.judging.refresh();
      expect(
        c.judging.canIssue(JudgeEventKind.remark, c.session.session.a.id),
        isFalse,
      );
      server.denyJudgingRead = 401;
      await c.judging.refresh();
      expect(c.judging.canIssue(JudgeEventKind.mutualHit, null), isFalse);
      expect(c.session.session.a.score, 7);
      expect(await store.entries(), isEmpty);
    },
  );
  test('HTTP judge payloads stay immutable after confirmation', () async {
    final r = await queue();
    expect(() => r.judgeEvent!['type'] = 'WARNING', throwsUnsupportedError);
    expect(
      () => object(r.judgeEvent!['score_snapshot'])['score_a'] = 100,
      throwsUnsupportedError,
    );
    expect(r.body['event']['score_snapshot']['score_a'], 7);
  });
  test(
    'an accepted judge event permits a normal result using the acknowledged version',
    () async {
      final c = await coordinator();
      await c.judging.confirm(JudgeEventKind.mutualHit);
      final w = worker();
      await w.flush();
      await w.shutdown();
      await c.judging.reloadLocal();
      await c.recorder.flush();
      final saved = c.recorder.snapshot();
      final result = PendingSubmission.confirm(
        origin: saved.origin,
        bout: saved.bout,
        session: saved.session,
        deviceId: deviceId,
      );
      await store.confirm(
        result,
        saved,
        credential,
        expectedDraftRevision: c.recorder.revision,
      );
      final sender = worker();
      await sender.flush();
      await sender.shutdown();
      expect(
        (await store.entry(result.clientEventId))!.state,
        OutboxState.acknowledged,
      );
      expect(server.judgeMutations, 1);
      expect(server.mutations, 1);
      expect(result.version, greaterThan(c.judging.initialBout.version));
    },
  );
  test(
    'schema v1 upgrades without losing or rewriting a pending result',
    () async {
      final saved = snapshot();
      final request = PendingSubmission.confirm(
        origin: saved.origin,
        bout: saved.bout,
        session: saved.session,
        deviceId: deviceId,
      );
      await store.confirm(request, saved, credential);
      await store.close();
      final legacy = await databaseFactoryFfi.openDatabase(
        '${dir.path}/test.sqlite',
      );
      await legacy.execute('DROP INDEX one_local_result_per_bout');
      await legacy.execute('ALTER TABLE outbox DROP COLUMN operation');
      await legacy.execute('ALTER TABLE outbox DROP COLUMN prepared_request');
      await legacy.execute(
        'CREATE UNIQUE INDEX one_local_result_per_bout ON outbox(origin,bout_id)',
      );
      await legacy.execute('PRAGMA user_version=1');
      await legacy.close();
      store = await TournamentStore.open(
        databaseFactoryFfi,
        '${dir.path}/test.sqlite',
      );
      expect((await store.entries()).single.request.toJson(), request.toJson());
      expect(await store.hasResult(request.origin, request.boutId), isTrue);
      expect(
        (await store.db.rawQuery('PRAGMA user_version')).single.values.single,
        2,
      );
    },
  );
  test(
    'a state change during confirmation retains the original event as review evidence',
    () async {
      final c = await coordinator(),
          basis = c.judging.state!,
          captured = c.recorder.snapshot();
      final changed = clone(server.judging);
      object(changed['bout'])['entity_version'] = basis.bout.version + 1;
      server.judging = changed;
      server.current = clone(object(changed['bout']));
      await c.judging.refresh();
      expect(c.judging.changed, isTrue);
      await c.judging.confirm(
        JudgeEventKind.mutualHit,
        basis: basis,
        captured: captured,
      );
      final entry = (await store.entries()).single;
      expect(entry.state, OutboxState.conflict);
      expect(entry.request.version, basis.bout.version);
      final w = worker();
      await w.flush();
      await w.shutdown();
      expect(server.writes, isEmpty);
    },
  );
  test(
    'failed local confirmation retains one stable request for explicit persistence retry',
    () async {
      final c = await coordinator();
      await store.db.execute(
        "CREATE TRIGGER reject_judge BEFORE INSERT ON outbox BEGIN SELECT RAISE(ABORT, 'synthetic disk failure'); END",
      );
      await c.judging.confirm(JudgeEventKind.mutualHit);
      final original = c.judging.unsavedRequest!;
      expect(c.judging.canIssue(JudgeEventKind.mutualHit, null), isFalse);
      expect(await store.entries(), isEmpty);
      await store.db.execute('DROP TRIGGER reject_judge');
      await c.judging.retryLocalSave();
      expect(
        (await store.entries()).single.request.toJson(),
        original.toJson(),
      );
      expect(c.judging.unsavedRequest, isNull);
    },
  );
  test(
    'competing completed server results never replace the active local score draft',
    () async {
      final c = await coordinator();
      c.session.setScore(DisplaySide.left, 11);
      c.session.setScore(DisplaySide.right, 2);
      final local = c.session.session;
      final other = clone(server.judging);
      object(other['bout']).addAll({
        'entity_version': c.judging.bout.version + 1,
        'score_a': 5,
        'score_b': 3,
        'status': 'COMPLETED',
        'result_type': 'NORMAL',
      });
      server.judging = other;
      server.current = clone(object(other['bout']));
      await c.judging.refresh();
      expect(identical(c.session.session, local), isTrue);
      expect(c.judging.changed, isTrue);
      expect(c.judging.competingState!.bout.scoreA, 5);
      expect(c.judging.canReview, isFalse);
      expect(c.judging.canIssue(JudgeEventKind.mutualHit, null), isFalse);
    },
  );
}
