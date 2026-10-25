import 'package:gdf_hema_timer/modules/opossum/submission_controller.dart';
import 'package:gdf_hema_timer/modules/bout_session/bout_session_controller.dart';
import 'package:gdf_hema_timer/modules/bout_session/bout_session.dart';
import 'package:gdf_hema_timer/modules/opossum/session_recorder.dart';
import 'package:gdf_hema_timer/modules/opossum/cached_client.dart';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:gdf_hema_timer/modules/opossum/api_client.dart';
import 'package:gdf_hema_timer/modules/opossum/models.dart';
import 'package:gdf_hema_timer/modules/opossum/outbox_sync.dart';
import 'package:gdf_hema_timer/modules/opossum/pending_submission.dart';
import 'package:gdf_hema_timer/modules/opossum/session_snapshot.dart';
import 'package:gdf_hema_timer/modules/opossum/tournament_store.dart';
import 'support/opossum_fixture.dart';

SessionSnapshot makeSnapshot(TimerBout bout) => SessionSnapshot(
  origin: 'https://example.test',
  nomination: NominationRef.fromJson(
    object(array(object(fixture()['discovery'])['nominations']).first),
  ),
  bout: bout,
  session: bout.toSession().copyWith(
    a: bout.toSession().a.copyWith(score: 5),
    b: bout.toSession().b.copyWith(score: 1),
    leftIsA: false,
  ),
  remainingMs: 45678,
  configuredMs: 90000,
  wasRunning: true,
  events: [],
  savedAt: DateTime.now().toUtc(),
);
void main() {
  sqfliteFfiInit();
  late Directory dir;
  late TournamentStore store;
  late FakeTimerServer server;
  late HttpOpossumClient api;
  final credential = credentialFingerprint(syntheticToken);
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('timer-durable-');
    store = await TournamentStore.open(
      databaseFactoryFfi,
      '${dir.path}/test.sqlite',
    );
    server = FakeTimerServer();
    api = HttpOpossumClient(
      ConnectionConfig('https://example.test', syntheticToken),
      client: server.client(),
      timeout: const Duration(milliseconds: 30),
      readRetries: 0,
    );
  });
  tearDown(() async {
    api.close();
    await store.close();
    await dir.delete(recursive: true);
  });
  Future<PendingSubmission> confirm({
    TimerBout? bout,
    List<String> dependencies = const [],
  }) async {
    final snapshot = makeSnapshot(bout ?? TimerBout.fromJson(server.current));
    final r = PendingSubmission.confirm(
      origin: snapshot.origin,
      bout: snapshot.bout,
      session: snapshot.session,
      deviceId: deviceId,
    );
    await store.confirm(r, snapshot, credential, dependencies: dependencies);
    return r;
  }

  OutboxSync worker() => OutboxSync(
    store: store,
    api: api,
    origin: 'https://example.test',
    credentialRef: credential,
  );
  test(
    'confirmed result and session survive database close/reopen with immutable identities',
    () async {
      final r = await confirm();
      await store.close();
      store = await TournamentStore.open(
        databaseFactoryFfi,
        '${dir.path}/test.sqlite',
      );
      final entry = (await store.entries()).single;
      expect(entry.request.toJson(), r.toJson());
      expect(entry.snapshot.remainingMs, 45678);
      expect(entry.snapshot.session.leftIsA, isFalse);
      expect(entry.state, OutboxState.pending);
      final w = worker();
      await w.flush();
      w.dispose();
      expect(
        (await store.entry(r.clientEventId))!.state,
        OutboxState.acknowledged,
      );
      expect(server.mutations, 1);
    },
  );
  test(
    'timeout after acceptance survives reopen and retries original key despite completed server state',
    () async {
      server.loseFirstReceipt = true;
      final r = await confirm();
      final w = worker();
      await w.flush();
      w.dispose();
      expect(server.mutations, 1);
      await store.close();
      store = await TournamentStore.open(
        databaseFactoryFfi,
        '${dir.path}/test.sqlite',
      );
      await store.retryTransport(r.origin);
      final resumed = worker();
      await resumed.flush();
      resumed.dispose();
      final e = (await store.entry(r.clientEventId))!;
      expect(e.state, OutboxState.acknowledged);
      expect(e.receipt!['replayed'], isTrue);
      expect(server.mutations, 1);
      expect(server.writes.map((r) => r.headers['idempotency-key']).toSet(), {
        r.idempotencyKey,
      });
    },
  );
  test(
    'interrupted SENDING is reclaimed only after its lease and uses identical request',
    () async {
      final r = await confirm();
      final time = DateTime.now();
      await store.claim(r.origin, 'dead-process', time);
      await store.dispatched(r.clientEventId, 'dead-process');
      final current = await store.claim(
        r.origin,
        'new-process',
        time.add(const Duration(seconds: 1)),
      );
      expect(current, isNull);
      await store.close();
      store = await TournamentStore.open(
        databaseFactoryFfi,
        '${dir.path}/test.sqlite',
      );
      final w = OutboxSync(
        store: store,
        api: api,
        origin: r.origin,
        credentialRef: credential,
        now: () => time.add(const Duration(seconds: 121)),
      );
      await w.flush();
      w.dispose();
      expect(
        (await store.entry(r.clientEventId))!.state,
        OutboxState.acknowledged,
      );
      expect(server.mutations, 1);
    },
  );
  test('concurrent senders cannot send the same queued result twice', () async {
    final r = await confirm();
    final other = await TournamentStore.open(
      databaseFactoryFfi,
      '${dir.path}/test.sqlite',
    );
    final a = worker(),
        b = OutboxSync(
          store: other,
          api: api,
          origin: r.origin,
          credentialRef: credential,
        );
    await Future.wait([a.flush(), a.flush(), b.flush()]);
    a.dispose();
    b.dispose();
    await other.close();
    expect(server.writes, hasLength(1));
    expect(server.mutations, 1);
  });
  test(
    'failed transaction leaves neither a half-confirmed session nor an outbox row',
    () async {
      final s = makeSnapshot(TimerBout.fromJson(server.current));
      await store.saveDraft(s, 0);
      await store.db.execute(
        "CREATE TRIGGER fail_outbox BEFORE INSERT ON outbox BEGIN SELECT RAISE(ABORT,'synthetic disk failure'); END",
      );
      final r = PendingSubmission.confirm(
        origin: s.origin,
        bout: s.bout,
        session: s.session,
        deviceId: deviceId,
      );
      await expectLater(
        store.confirm(r, s, credential, expectedDraftRevision: 1),
        throwsA(anything),
      );
      expect(await store.entries(), isEmpty);
      expect((await store.draft(s.origin, s.bout.id))!.revision, 1);
    },
  );
  test(
    'stale version or changed pairing preserves the local result as conflict',
    () async {
      final r = await confirm();
      server.current = {
        ...server.current,
        'entity_version': integer(server.current['entity_version']) + 1,
      };
      final w = worker();
      await w.flush();
      w.dispose();
      final e = (await store.entry(r.clientEventId))!;
      expect(e.state, OutboxState.conflict);
      expect(e.request.scoreA, 5);
      expect(e.serverBout, isNotNull);
      expect(server.writes, isEmpty);
    },
  );
  test(
    'finalization/cancellation rejects first-time replay without losing evidence',
    () async {
      final r = await confirm();
      server.current = {
        ...server.current,
        'stage_status': 'FINALIZED',
        'availability': {'available': false, 'reason': 'STAGE_LOCKED'},
      };
      final w = worker();
      await w.flush();
      w.dispose();
      expect((await store.entry(r.clientEventId))!.state, OutboxState.rejected);
      expect(server.writes, isEmpty);
      expect(await store.unresolvedCount(), 1);
    },
  );
  test(
    'revoked or replaced credential pauses queue and never deletes pending evidence',
    () async {
      final r = await confirm();
      final bad = HttpOpossumClient(
        ConnectionConfig('https://example.test', 'revoked-token'),
        client: server.client(),
        readRetries: 0,
      );
      final w = OutboxSync(
        store: store,
        api: bad,
        origin: r.origin,
        credentialRef: credential,
      );
      await w.flush();
      w.dispose();
      bad.close();
      expect(
        (await store.entry(r.clientEventId))!.state,
        OutboxState.authentication,
      );
      expect(server.writes, isEmpty);
      await store.retryTransport(r.origin);
      final changed = OutboxSync(
        store: store,
        api: api,
        origin: r.origin,
        credentialRef: 'different-credential',
      );
      await changed.flush();
      changed.dispose();
      expect(
        (await store.entry(r.clientEventId))!.errorCode,
        'CREDENTIAL_CHANGED',
      );
      expect(await store.unresolvedCount(), 1);
    },
  );
  test(
    'cache refuses a lower authoritative revision and contains no credential',
    () async {
      await store.cache('work', {'value': 2}, '2', DateTime.now());
      await store.cache('work', {'value': 1}, '1', DateTime.now());
      expect((await store.cached('work'))!.body['value'], 2);
      await confirm();
      final file = File('${dir.path}/test.sqlite').readAsBytesSync();
      expect(
        utf8.decode(file, allowMalformed: true),
        isNot(contains(syntheticToken)),
      );
    },
  );
  test(
    'a separate process exits without closing SQLite; another process recovers its confirmed result',
    () async {
      final root = Platform.environment['FLUTTER_ROOT'];
      final dart = root == null
          ? Platform.resolvedExecutable
          : '$root/bin/dart';
      final input = File('${dir.path}/snapshot.json');
      input.writeAsStringSync(
        jsonEncode(makeSnapshot(TimerBout.fromJson(server.current)).toJson()),
      );
      final path = '${dir.path}/process.sqlite';
      final written = await Process.run(dart, [
        'run',
        'tool/opossum_storage_probe.dart',
        'write',
        path,
        input.path,
      ]);
      expect(written.exitCode, 0, reason: '${written.stderr}');
      final read = await Process.run(dart, [
        'run',
        'tool/opossum_storage_probe.dart',
        'read',
        path,
        input.path,
      ]);
      expect(read.exitCode, 0, reason: '${read.stderr}');
      final value = object(
        jsonDecode((read.stdout as String).trim().split('\n').last),
      );
      expect(value['state'], 'pending');
      expect(value['score_a'], 5);
      expect(value['remaining_ms'], 45678);
      expect(value['was_running'], isTrue);
      expect(
        (written.stdout as String).trim().split('\n').last,
        value['event_id'],
      );
    },
  );
  test(
    'causal dependency waits after a conflict while an unrelated bout can proceed',
    () async {
      final first = await confirm();
      final items = array(
        object(
          array(
            object(
              array(object(server.data['worklist'])['piste_worklists']).first,
            )['segments'],
          ).first,
        )['items'],
      );
      final secondBout = TimerBout.fromJson(object(object(items[1])['bout'])),
          thirdBout = TimerBout.fromJson(object(object(items[2])['bout']));
      final second = await confirm(
        bout: secondBout,
        dependencies: [first.clientEventId],
      );
      final third = await confirm(bout: thirdBout);
      await store.claim(first.origin, 'review', DateTime.now());
      await store.finish(
        first.clientEventId,
        'review',
        OutboxState.conflict,
        code: 'SYNTHETIC_CONFLICT',
      );
      final next = await store.claim(first.origin, 'worker', DateTime.now());
      expect(next!.request.clientEventId, third.clientEventId);
      await store.finish(
        third.clientEventId,
        'worker',
        OutboxState.acknowledged,
        receipt: {'synthetic': 'test'},
      );
      expect(await store.claim(first.origin, 'worker', DateTime.now()), isNull);
      expect(
        (await store.entry(second.clientEventId))!.state,
        OutboxState.pending,
      );
    },
  );
  test(
    'two devices confirming the same server version retain the second conflict',
    () async {
      final r = await confirm();
      final other = await TournamentStore.open(
        databaseFactoryFfi,
        '${dir.path}/second-device.sqlite',
      );
      final snapshot = makeSnapshot(TimerBout.fromJson(server.current));
      final competing = PendingSubmission.confirm(
        origin: r.origin,
        bout: snapshot.bout,
        session: snapshot.session.copyWith(
          a: snapshot.session.a.copyWith(score: 8),
        ),
        deviceId: '00000000-0000-4000-8000-000000000ffe',
      );
      await other.confirm(
        competing,
        SessionSnapshot(
          origin: snapshot.origin,
          nomination: snapshot.nomination,
          bout: snapshot.bout,
          session: snapshot.session.copyWith(
            a: snapshot.session.a.copyWith(score: 8),
          ),
          remainingMs: snapshot.remainingMs,
          configuredMs: snapshot.configuredMs,
          wasRunning: false,
          events: [],
          savedAt: snapshot.savedAt,
        ),
        credential,
      );
      final a = worker(),
          b = OutboxSync(
            store: other,
            api: api,
            origin: r.origin,
            credentialRef: credential,
          );
      await a.flush();
      await b.flush();
      a.dispose();
      b.dispose();
      expect(server.mutations, 1);
      expect(
        (await other.entry(competing.clientEventId))!.state,
        OutboxState.conflict,
      );
      expect((await other.entry(competing.clientEventId))!.request.scoreA, 8);
      await other.close();
    },
  );
  test(
    'a pairing changed at the same entity version is never rebound locally',
    () async {
      final r = await confirm();
      server.current = {
        ...server.current,
        'fighter_a': {
          'fighter_id': '00000000-0000-4000-8000-000000000eee',
          'display_name': 'Different synthetic fighter',
        },
      };
      final w = worker();
      await w.flush();
      w.dispose();
      expect((await store.entry(r.clientEventId))!.state, OutboxState.conflict);
      expect(server.writes, isEmpty);
    },
  );
  test(
    'offline scoring/history/clock checkpoint restores paused without guessing elapsed time',
    () async {
      final b = TimerBout.fromJson(server.current),
          s = makeSnapshot(TimerBout.fromJson(server.current));
      var elapsed = Duration.zero;
      final controller = BoutSessionController(
        initialSession: b.toSession(),
        elapsed: () => elapsed,
      );
      final recorder = SessionRecorder(
        store: store,
        controller: controller,
        origin: s.origin,
        nomination: s.nomination,
        bout: b,
        configuredMs: 90000,
      );
      controller.setScore(DisplaySide.left, 5);
      controller.setScore(DisplaySide.right, 1);
      controller.setMutualHits(2);
      controller.swapSides();
      controller.start();
      elapsed = const Duration(seconds: 7);
      recorder.checkpoint();
      await recorder.flush();
      final persisted = (await store.draft(s.origin, b.id))!;
      recorder.dispose();
      controller.dispose();
      await store.close();
      store = await TournamentStore.open(
        databaseFactoryFfi,
        '${dir.path}/test.sqlite',
      );
      final saved = (await store.draft(s.origin, b.id))!;
      final recovered = BoutSessionController(initialSession: b.toSession());
      recovered.restore(
        session: saved.snapshot.session,
        remaining: Duration(milliseconds: saved.snapshot.remainingMs),
        events: saved.snapshot.events,
        timingUncertain: saved.snapshot.wasRunning,
      );
      expect(persisted.snapshot.remainingMs, 83000);
      expect(recovered.running, isFalse);
      expect(recovered.interrupted, isTrue);
      expect(recovered.session.a.score, 5);
      expect(recovered.session.b.score, 1);
      expect(recovered.session.mutualHits, 2);
      expect(recovered.session.leftIsA, isFalse);
      expect(recovered.fightLog.events, hasLength(5));
      expect(server.reads, 0);
      recovered.dispose();
    },
  );
  test(
    'failed acknowledgement persistence replays without duplicating server mutation',
    () async {
      final r = await confirm();
      await store.db.execute(
        "CREATE TRIGGER fail_ack BEFORE UPDATE OF receipt ON outbox WHEN NEW.receipt IS NOT NULL BEGIN SELECT RAISE(ABORT,'synthetic full disk'); END",
      );
      final w = worker();
      await expectLater(w.flush(), throwsA(anything));
      expect(server.mutations, 1);
      expect((await store.entry(r.clientEventId))!.state, OutboxState.sending);
      await w.flush();
      expect(server.writes, hasLength(1));
      await store.db.execute('DROP TRIGGER fail_ack');
      await w.retry();
      w.dispose();
      expect(
        (await store.entry(r.clientEventId))!.state,
        OutboxState.acknowledged,
      );
      expect(server.mutations, 1);
    },
  );
  test(
    'cached READY work survives network loss, but authentication denial is not hidden by cache',
    () async {
      final n = makeSnapshot(TimerBout.fromJson(server.current)).nomination;
      final cached = CachedOpossumClient(
        network: api,
        store: store,
        origin: 'https://example.test',
      );
      final online = await cached.worklist(n);
      server.failReads = true;
      final stale = await cached.worklist(n);
      expect(stale.serverRevision, online.serverRevision);
      expect(cached.offline, isTrue);
      expect(
        (await cached.bout(server.current['bout_id'] as String)).writable,
        isTrue,
      );
      final denied = CachedOpossumClient(
        network: HttpOpossumClient(
          ConnectionConfig('https://example.test', 'revoked'),
          client: server.client(),
          readRetries: 0,
        ),
        store: store,
        origin: 'https://example.test',
      );
      await expectLater(
        denied.worklist(n),
        throwsA(
          isA<OpossumException>().having(
            (e) => e.kind,
            'kind',
            ApiFailure.authentication,
          ),
        ),
      );
      denied.close();
    },
  );
  test(
    'a 409 received after preflight retains the exact request and server snapshot',
    () async {
      final r = await confirm();
      server.denyWrites = 409;
      final w = worker();
      await w.flush();
      w.dispose();
      final e = (await store.entry(r.clientEventId))!;
      expect(e.state, OutboxState.conflict);
      expect(e.request.toJson(), r.toJson());
      expect(e.serverBout, isNotNull);
      expect(await store.unresolvedCount(), 1);
    },
  );
  test('confirmation rejects another tab changing the saved draft', () async {
    final snapshot = makeSnapshot(TimerBout.fromJson(server.current));
    final revision = await store.saveDraft(snapshot, 0);
    await store.saveDraft(snapshot, revision);
    final request = PendingSubmission.confirm(
      origin: snapshot.origin,
      bout: snapshot.bout,
      session: snapshot.session,
      deviceId: deviceId,
    );
    await expectLater(
      store.confirm(
        request,
        snapshot,
        credential,
        expectedDraftRevision: revision,
      ),
      throwsStateError,
    );
    expect(await store.entries(), isEmpty);
    expect((await store.draft(snapshot.origin, snapshot.bout.id))!.revision, 2);
    await store.confirm(
      request,
      snapshot,
      credential,
      expectedDraftRevision: 2,
    );
    expect(await store.entries(), hasLength(1));
  });
  test(
    'manual transport retry respects a persisted rate-limit deadline',
    () async {
      final request = await confirm();
      final now = DateTime.now();
      await store.claim(request.origin, 'sender', now);
      await store.finish(
        request.clientEventId,
        'sender',
        OutboxState.pending,
        code: 'RATE_LIMITED',
        next: now.add(const Duration(minutes: 1)),
      );
      await store.retryTransport(request.origin);
      expect(await store.claim(request.origin, 'sender', now), isNull);
      expect(
        await store.claim(
          request.origin,
          'sender',
          now.add(const Duration(minutes: 2)),
        ),
        isNotNull,
      );
    },
  );
  test(
    'resolved-at-desk dependency is retained and never grants submission authority',
    () async {
      final first = await confirm();
      final n = makeSnapshot(TimerBout.fromJson(server.current)).nomination;
      final work = await api.worklist(n);
      final other = work.assignments
          .expand((s) => s.items)
          .map((i) => i.bout)
          .firstWhere((b) => b.id != first.boutId);
      final second = await confirm(
        bout: other,
        dependencies: [first.clientEventId],
      );
      await expectLater(
        store.handled(second.clientEventId, 'Too early', DateTime.now()),
        throwsStateError,
      );
      await store.claim(first.origin, 'review', DateTime.now());
      await store.finish(first.clientEventId, 'review', OutboxState.conflict);
      await store.handled(
        first.clientEventId,
        'Reviewed at organizer desk',
        DateTime.now(),
      );
      expect(await store.claim(first.origin, 'sender', DateTime.now()), isNull);
      await store.handled(
        second.clientEventId,
        'Dependent result reviewed at organizer desk',
        DateTime.now(),
      );
      expect(await store.entries(), hasLength(2));
      expect(await store.unresolvedCount(), 0);
      expect(
        (await store.entry(first.clientEventId))!.request.toJson(),
        first.toJson(),
      );
      expect(server.writes, isEmpty);
    },
  );
  test(
    'durable confirmation failure preserves the draft and stable retry identity',
    () async {
      final snapshot = makeSnapshot(TimerBout.fromJson(server.current));
      final revision = await store.saveDraft(snapshot, 0);
      await store.db.execute(
        "CREATE TRIGGER fail_confirmation BEFORE INSERT ON outbox BEGIN SELECT RAISE(ABORT,'synthetic storage failure'); END",
      );
      final w = worker();
      final c = SubmissionController(
        api: api,
        repository: store,
        origin: snapshot.origin,
        nomination: snapshot.nomination,
        bout: snapshot.bout,
        session: snapshot.session,
        deviceId: deviceId,
        outbox: w,
        snapshot: snapshot,
        credentialRef: credential,
        expectedDraftRevision: revision,
      );
      await Future.wait([c.confirm(), c.confirm()]);
      final original = c.request!.toJson();
      expect(c.savedLocally, isFalse);
      expect(c.error!.kind, ApiFailure.localPersistence);
      expect(await store.entries(), isEmpty);
      expect(
        (await store.draft(snapshot.origin, snapshot.bout.id))!.revision,
        revision,
      );
      expect(server.writes, isEmpty);
      await store.db.execute('DROP TRIGGER fail_confirmation');
      await c.confirm();
      expect(c.request!.toJson(), original);
      expect(c.savedLocally, isTrue);
      expect(c.state, SubmissionState.accepted);
      expect(await store.entries(), hasLength(1));
      expect(server.mutations, 1);
      c.dispose();
      w.dispose();
    },
  );
  test(
    'expired uncertain requests require explicit desk review, never a new key',
    () async {
      final request = await confirm();
      final w = OutboxSync(
        store: store,
        api: api,
        origin: request.origin,
        credentialRef: credential,
        now: () =>
            DateTime.parse(request.submittedAt).add(const Duration(days: 29)),
      );
      await w.flush();
      final entry = (await store.entry(request.clientEventId))!;
      expect(entry.state, OutboxState.conflict);
      expect(entry.errorCode, 'IDEMPOTENCY_REVIEW_REQUIRED');
      expect(entry.request.toJson(), request.toJson());
      expect(server.writes, isEmpty);
      w.dispose();
    },
  );
  test(
    'offline bout cache selects the latest authoritative snapshot',
    () async {
      final cached = CachedOpossumClient(
        network: api,
        store: store,
        origin: 'https://example.test',
      );
      final n = makeSnapshot(TimerBout.fromJson(server.current)).nomination;
      final old = await cached.bout(server.current['bout_id'] as String);
      server.current = {
        ...server.current,
        'entity_version': old.version + 1,
        'tournament_revision': (BigInt.parse(old.serverRevision) + BigInt.one)
            .toString(),
        'status': 'CANCELLED',
        'availability': {'available': false, 'reason': 'BOUT_CANCELLED'},
      };
      await cached.worklist(n);
      server.failReads = true;
      final fresh = await cached.bout(old.id);
      expect(fresh.version, old.version + 1);
      expect(fresh.writable, isFalse);
      expect(fresh.status, 'CANCELLED');
    },
  );
  test(
    'preflight outages back off durably and stop automatic requests until explicit retry',
    () async {
      final request = await confirm();
      var now = DateTime.fromMillisecondsSinceEpoch(DateTime.now().millisecondsSinceEpoch, isUtc: true);
      final w = OutboxSync(
        store: store,
        api: api,
        origin: request.origin,
        credentialRef: credential,
        now: () => now,
      );
      server.failReads = true;
      for (var attempt = 1; attempt <= 8; attempt++) {
        await w.flush();
        final e = (await store.entry(request.clientEventId))!;
        expect(e.attempts, attempt);
        if (attempt < 8) {
          expect(e.state, OutboxState.pending);
          expect(
            e.nextAttempt.difference(now),
            Duration(
              seconds: 2 * (1 << (attempt - 1)) > 120
                  ? 120
                  : 2 * (1 << (attempt - 1)),
            ),
          );
        } else {
          expect(e.state, OutboxState.retryPaused);
        }
        await w.flush();
        expect(server.reads, attempt);
        now = now.add(const Duration(minutes: 3));
      }
      await w.flush();
      expect(server.reads, 8);
      expect(server.writes, isEmpty);
      server.failReads = false;
      await w.retry();
      expect(
        (await store.entry(request.clientEventId))!.state,
        OutboxState.acknowledged,
      );
      expect(server.mutations, 1);
      expect(
        server.writes.single.headers['idempotency-key'],
        request.idempotencyKey,
      );
      w.dispose();
    },
  );
}
