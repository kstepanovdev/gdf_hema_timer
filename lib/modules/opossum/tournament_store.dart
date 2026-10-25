import 'dart:convert';
import 'package:sqflite_common/sqlite_api.dart';
import 'models.dart';
import 'pending_submission.dart';
import 'session_snapshot.dart';
import 'judging.dart';

enum OutboxState {
  pending,
  sending,
  acknowledged,
  authentication,
  retryPaused,
  conflict,
  rejected,
  handled,
  cancelled,
}

class OutboxEntry {
  OutboxEntry.fromRow(Map<String, Object?> row)
    : sequence = row['seq'] as int,
      request = PendingSubmission.fromJson(
        object(
          jsonDecode((row['prepared_request'] ?? row['request']) as String),
        ),
      ),
      intent = PendingSubmission.fromJson(
        object(jsonDecode(row['request'] as String)),
      ),
      prepared = row['prepared_request'] != null,
      snapshot = SessionSnapshot.fromJson(
        object(jsonDecode(row['snapshot'] as String)),
      ),
      state = OutboxState.values.byName(row['state'] as String),
      attempts = row['attempts'] as int,
      dispatched = row['dispatched'] == 1,
      nextAttempt = DateTime.fromMillisecondsSinceEpoch(
        row['next_attempt'] as int,
        isUtc: true,
      ),
      credentialRef = row['credential_ref'] as String,
      errorCode = row['error_code'] as String?,
      receipt = row['receipt'] == null
          ? null
          : object(jsonDecode(row['receipt'] as String)),
      serverBout = row['server_bout'] == null
          ? null
          : TimerBout.fromJson(
              object(jsonDecode(row['server_bout'] as String)),
            ),
      dependencies = (jsonDecode(row['dependencies'] as String) as List)
          .cast<String>();
  final int sequence, attempts;
  final PendingSubmission request;
  final PendingSubmission intent;
  final bool prepared;
  final SessionSnapshot snapshot;
  final OutboxState state;
  final DateTime nextAttempt;
  final String credentialRef;
  final bool dispatched;
  final String? errorCode;
  final Json? receipt;
  final TimerBout? serverBout;
  final List<String> dependencies;
  bool get unresolved =>
      state != OutboxState.acknowledged &&
      state != OutboxState.handled &&
      state != OutboxState.cancelled;
}

class StoredDraft {
  StoredDraft(this.snapshot, this.revision);
  final SessionSnapshot snapshot;
  final int revision;
}

class CachedSnapshot {
  CachedSnapshot(this.body, this.savedAt);
  final Json body;
  final DateTime savedAt;
}

/// SQLite is the durability boundary. No bearer token is accepted by this API.
class TournamentStore implements PendingSubmissionRepository {
  TournamentStore._(this.db, this.evictionProtected);
  final bool evictionProtected;
  final Database db;
  static Future<TournamentStore> open(
    DatabaseFactory factory,
    String path, {
    bool writeAheadLog = true,
    bool singleInstance = false,
    bool evictionProtected = true,
  }) async {
    final db = await factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 2,
        singleInstance: singleInstance,
        onConfigure: (db) async {
          await db.execute('PRAGMA foreign_keys = ON');
          await db.execute('PRAGMA busy_timeout = 250');
          if (writeAheadLog) await db.rawQuery('PRAGMA journal_mode = WAL');
          await db.execute('PRAGMA synchronous = FULL');
        },
        onCreate: (db, version) async {
          await db.execute(
            'CREATE TABLE metadata (key TEXT PRIMARY KEY, body TEXT NOT NULL)',
          );
          await db.execute(
            'CREATE TABLE cache (key TEXT PRIMARY KEY, body TEXT NOT NULL, revision TEXT NOT NULL, saved_at INTEGER NOT NULL)',
          );
          await db.execute(
            'CREATE TABLE sessions (key TEXT PRIMARY KEY, origin TEXT NOT NULL, nomination_id TEXT NOT NULL, bout_id TEXT NOT NULL, revision INTEGER NOT NULL, phase TEXT NOT NULL, body TEXT NOT NULL)',
          );
          await db.execute(
            'CREATE TABLE session_events (seq INTEGER PRIMARY KEY AUTOINCREMENT, session_key TEXT NOT NULL REFERENCES sessions(key), revision INTEGER NOT NULL, body TEXT NOT NULL, UNIQUE(session_key,revision))',
          );
          await db.execute(
            "CREATE TABLE outbox (seq INTEGER PRIMARY KEY AUTOINCREMENT, event_id TEXT NOT NULL UNIQUE, idempotency_key TEXT NOT NULL UNIQUE, origin TEXT NOT NULL, bout_id TEXT NOT NULL, request TEXT NOT NULL, snapshot TEXT NOT NULL, credential_ref TEXT NOT NULL, dependencies TEXT NOT NULL, state TEXT NOT NULL, attempts INTEGER NOT NULL DEFAULT 0, dispatched INTEGER NOT NULL DEFAULT 0, next_attempt INTEGER NOT NULL DEFAULT 0, error_code TEXT, server_bout TEXT, receipt TEXT, resolution TEXT)",
          );
          await db.execute(
            'CREATE UNIQUE INDEX one_local_result_per_bout ON outbox(origin,bout_id)',
          );
          await db.execute(
            'CREATE INDEX pending_order ON outbox(origin,state,next_attempt,seq)',
          );
          await db.execute(
            'CREATE TABLE sync_lease (id INTEGER PRIMARY KEY CHECK(id=1), owner TEXT, expires INTEGER NOT NULL)',
          );
          await db.insert('sync_lease', {'id': 1, 'owner': null, 'expires': 0});
          await _upgradeJudging(db);
        },
        onUpgrade: (db, old, version) async {
          if (old < 2) await _upgradeJudging(db);
        },
      ),
    );
    return TournamentStore._(db, evictionProtected);
  }

  static Future<void> _upgradeJudging(DatabaseExecutor db) async {
    await db.execute(
      "ALTER TABLE outbox ADD COLUMN operation TEXT NOT NULL DEFAULT 'result'",
    );
    await db.execute('ALTER TABLE outbox ADD COLUMN prepared_request TEXT');
    await db.execute('DROP INDEX one_local_result_per_bout');
    await db.execute(
      "CREATE UNIQUE INDEX one_local_result_per_bout ON outbox(origin,bout_id) WHERE operation='result'",
    );
  }

  @override
  bool get durable => true;
  static String sessionKey(String origin, String boutId) => '$origin|$boutId';
  Future<void> close() => db.close();
  Future<void> putMetadata(String key, Json value) => db
      .insert('metadata', {
        'key': key,
        'body': jsonEncode(value),
      }, conflictAlgorithm: ConflictAlgorithm.replace)
      .then((_) {});
  Future<Json?> metadata(String key) async {
    final rows = await db.query('metadata', where: 'key=?', whereArgs: [key]);
    return rows.isEmpty
        ? null
        : object(jsonDecode(rows.single['body'] as String));
  }

  Future<void> cacheDiscovery(String origin, List<NominationRef> latest) async {
    await db.transaction((tx) async {
      final key = 'discovery|$origin';
      final rows = await tx.query('metadata', where: 'key=?', whereArgs: [key]);
      final old = rows.isEmpty
          ? null
          : object(jsonDecode(rows.single['body'] as String));
      final known = <String, NominationRef>{
        if (old != null)
          for (final row in array(old['nominations']))
            NominationRef.fromJson(object(row)).id: NominationRef.fromJson(
              object(row),
            ),
        for (final n in latest) n.id: n,
      };
      await tx.insert('metadata', {
        'key': key,
        'body': jsonEncode({
          'nominations': known.values.map((n) => n.toJson()).toList(),
        }),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }

  Future<List<Json>> connections() async => (await db.query(
    'metadata',
    where: 'key LIKE ?',
    whereArgs: ['connection|%'],
  )).map((r) => object(jsonDecode(r['body'] as String))).toList();
  Future<void> cache(
    String key,
    Json body,
    String revision,
    DateTime now,
  ) async {
    await db.transaction((tx) async {
      final old = await tx.query('cache', where: 'key=?', whereArgs: [key]);
      if (old.isNotEmpty &&
          BigInt.parse(old.single['revision'] as String) >
              BigInt.parse(revision)) {
        return;
      }
      await tx.insert('cache', {
        'key': key,
        'body': jsonEncode(body),
        'revision': revision,
        'saved_at': now.toUtc().millisecondsSinceEpoch,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }

  Future<CachedSnapshot?> cached(String key) async {
    final rows = await db.query('cache', where: 'key=?', whereArgs: [key]);
    return rows.isEmpty
        ? null
        : CachedSnapshot(
            object(jsonDecode(rows.single['body'] as String)),
            DateTime.fromMillisecondsSinceEpoch(
              rows.single['saved_at'] as int,
              isUtc: true,
            ),
          );
  }

  Future<CachedSnapshot?> cachedBout(String origin, String id) async {
    final prefix = 'work|$origin|';
    final rows = await db.query(
      'cache',
      where: 'substr(key,1,?)=?',
      whereArgs: [prefix.length, prefix],
    );
    for (final row in rows) {
      final work = TimerWorklist.fromJson(
        object(jsonDecode(row['body'] as String)),
      );
      final bout = work.bout(id);
      if (bout != null) {
        return CachedSnapshot(
          bout.toJson(),
          DateTime.fromMillisecondsSinceEpoch(
            row['saved_at'] as int,
            isUtc: true,
          ),
        );
      }
    }
    return null;
  }

  Future<StoredDraft?> draft(String origin, String boutId) async {
    final rows = await db.query(
      'sessions',
      where: 'key=? AND phase=?',
      whereArgs: [sessionKey(origin, boutId), 'DRAFT'],
    );
    return rows.isEmpty
        ? null
        : StoredDraft(
            SessionSnapshot.fromJson(
              object(jsonDecode(rows.single['body'] as String)),
            ),
            rows.single['revision'] as int,
          );
  }

  Future<List<StoredDraft>> drafts(String origin, String nominationId) async =>
      (await db.query(
            'sessions',
            where: 'origin=? AND nomination_id=? AND phase=?',
            whereArgs: [origin, nominationId, 'DRAFT'],
          ))
          .map(
            (r) => StoredDraft(
              SessionSnapshot.fromJson(object(jsonDecode(r['body'] as String))),
              r['revision'] as int,
            ),
          )
          .toList();
  Future<int> saveDraft(SessionSnapshot snapshot, int expectedRevision) async =>
      db.transaction((tx) async {
        final key = sessionKey(snapshot.origin, snapshot.bout.id),
            rows = await tx.query('sessions', where: 'key=?', whereArgs: [key]);
        if (rows.isNotEmpty &&
            (rows.single['revision'] != expectedRevision ||
                rows.single['phase'] != 'DRAFT')) {
          throw StateError('Local session changed or confirmed');
        }
        if (rows.isEmpty && expectedRevision != 0) {
          throw StateError('Local session missing');
        }
        final revision = expectedRevision + 1;
        await tx.insert('sessions', {
          'key': key,
          'origin': snapshot.origin,
          'nomination_id': snapshot.nomination.id,
          'bout_id': snapshot.bout.id,
          'revision': revision,
          'phase': 'DRAFT',
          'body': jsonEncode(snapshot.toJson()),
        }, conflictAlgorithm: ConflictAlgorithm.replace);
        await tx.insert('session_events', {
          'session_key': key,
          'revision': revision,
          'body': jsonEncode(snapshot.toJson()),
        });
        return revision;
      });
  Future<void> confirm(
    PendingSubmission request,
    SessionSnapshot snapshot,
    String credentialRef, {
    List<String> dependencies = const [],
    int? expectedDraftRevision,
  }) async {
    if (request.isJudge) throw StateError('Use judging confirmation');
    if (request.origin != snapshot.origin ||
        request.boutId != snapshot.session.id ||
        request.fighterAId != snapshot.session.a.id ||
        request.fighterBId != snapshot.session.b.id ||
        request.scoreA != snapshot.session.a.score ||
        request.scoreB != snapshot.session.b.score ||
        request.version != snapshot.bout.version) {
      throw StateError('Result/session mismatch');
    }
    await db.transaction((tx) async {
      final old = await tx.query(
        'outbox',
        where: 'event_id=?',
        whereArgs: [request.clientEventId],
      );
      if (old.isNotEmpty) {
        if (old.single['request'] != jsonEncode(request.toJson()) ||
            old.single['snapshot'] != jsonEncode(snapshot.toJson())) {
          throw StateError('Immutable confirmation');
        }
        return;
      }
      final judging = await tx.query(
        'outbox',
        where:
            "origin=? AND bout_id=? AND operation='judge' AND state NOT IN (?,?)",
        whereArgs: [
          request.origin,
          request.boutId,
          OutboxState.acknowledged.name,
          OutboxState.cancelled.name,
        ],
      );
      if (judging.isNotEmpty) {
        throw StateError('Resolve judging events before confirming a result');
      }
      for (final dependency in dependencies) {
        if ((await tx.query(
          'outbox',
          where: 'event_id=? AND origin=?',
          whereArgs: [dependency, request.origin],
        )).isEmpty) {
          throw StateError('Unknown dependency');
        }
      }
      final key = sessionKey(request.origin, request.boutId),
          existing = await tx.query(
            'sessions',
            where: 'key=?',
            whereArgs: [key],
          );
      if (existing.isNotEmpty &&
          existing.single['revision'] != expectedDraftRevision) {
        throw StateError('Local draft changed before confirmation');
      }
      if (existing.isNotEmpty && existing.single['phase'] != 'DRAFT') {
        throw StateError('Already confirmed');
      }
      final revision =
          (existing.isEmpty ? 0 : existing.single['revision'] as int) + 1;
      await tx.insert('sessions', {
        'key': key,
        'origin': snapshot.origin,
        'nomination_id': snapshot.nomination.id,
        'bout_id': snapshot.bout.id,
        'revision': revision,
        'phase': 'CONFIRMED_LOCAL',
        'body': jsonEncode(snapshot.toJson()),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      await tx.insert('session_events', {
        'session_key': key,
        'revision': revision,
        'body': jsonEncode({
          'kind': 'CONFIRMED_LOCAL',
          'request': request.toJson(),
          'session': snapshot.toJson(),
        }),
      });
      await tx.insert('outbox', {
        'event_id': request.clientEventId,
        'idempotency_key': request.idempotencyKey,
        'origin': request.origin,
        'bout_id': request.boutId,
        'request': jsonEncode(request.toJson()),
        'snapshot': jsonEncode(snapshot.toJson()),
        'credential_ref': credentialRef,
        'dependencies': jsonEncode(dependencies),
        'state': OutboxState.pending.name,
      });
    });
  }

  /// The confirmed local action, captured session and immutable intent share one
  /// transaction. Official session counters do not change until acknowledgement.
  Future<void> confirmJudge(
    PendingSubmission request,
    SessionSnapshot snapshot,
    String credentialRef, {
    bool reviewRequired = false,
  }) async {
    if (!request.isJudge ||
        request.origin != snapshot.origin ||
        request.tournamentId != snapshot.bout.tournamentId ||
        request.nominationId != snapshot.bout.nominationId ||
        request.boutId != snapshot.session.id ||
        request.fighterAId != snapshot.session.a.id ||
        request.fighterBId != snapshot.session.b.id ||
        request.scoreA != snapshot.session.a.score ||
        request.scoreB != snapshot.session.b.score) {
      throw StateError('Judge/session mismatch');
    }
    await db.transaction((tx) async {
      final old = await tx.query(
        'outbox',
        where: 'event_id=?',
        whereArgs: [request.clientEventId],
      );
      if (old.isNotEmpty) {
        if (old.single['request'] != jsonEncode(request.toJson())) {
          throw StateError('Immutable event');
        }
        return;
      }
      final rows = await tx.query(
        'outbox',
        where: 'origin=? AND bout_id=?',
        whereArgs: [request.origin, request.boutId],
        orderBy: 'seq',
      );
      final existing = rows.map(OutboxEntry.fromRow).toList();
      final needsReview =
          reviewRequired ||
          existing.any(
            (e) =>
                !e.request.isJudge ||
                [
                  OutboxState.conflict,
                  OutboxState.rejected,
                  OutboxState.authentication,
                  OutboxState.handled,
                ].contains(e.state),
          );
      final pending = existing.where((e) => e.unresolved).toList();
      if (pending.any((e) => e.credentialRef != credentialRef)) {
        throw StateError('Credential changed');
      }
      await tx.insert('outbox', {
        'event_id': request.clientEventId,
        'idempotency_key': request.idempotencyKey,
        'origin': request.origin,
        'bout_id': request.boutId,
        'operation': 'judge',
        'request': jsonEncode(request.toJson()),
        'snapshot': jsonEncode(snapshot.toJson()),
        'credential_ref': credentialRef,
        'dependencies': jsonEncode(
          pending.isEmpty ? [] : [pending.last.request.clientEventId],
        ),
        'state': needsReview
            ? OutboxState.conflict.name
            : OutboxState.pending.name,
        if (needsReview) 'error_code': 'ORGANIZER_REVIEW_REQUIRED',
      });
    });
  }

  /// Bind an unsent dependent intent ONLY to its designated predecessor's
  /// durable acknowledgement. Never refresh a stale request version on retry.
  Future<OutboxEntry> prepareJudge(String id, String owner) async =>
      db.transaction((tx) async {
        await _owns(tx, owner);
        final row = (await tx.query(
          'outbox',
          where: 'event_id=?',
          whereArgs: [id],
        )).single;
        final entry = OutboxEntry.fromRow(row);
        if (entry.prepared || !entry.request.isJudge) return entry;
        var request = entry.intent;
        if (entry.dependencies.isNotEmpty) {
          final dep = OutboxEntry.fromRow(
            (await tx.query(
              'outbox',
              where: 'event_id=?',
              whereArgs: [entry.dependencies.single],
            )).single,
          );
          if (dep.state != OutboxState.acknowledged ||
              dep.receipt == null ||
              !dep.request.isJudge ||
              dep.credentialRef != entry.credentialRef) {
            throw StateError('Unacknowledged judging dependency');
          }
          final state = JudgingReceipt.fromJson(dep.receipt!).state;
          if (state.bout.id != request.boutId ||
              state.bout.tournamentId != request.tournamentId ||
              state.bout.nominationId != request.nominationId ||
              state.bout.a?.id != request.fighterAId ||
              state.bout.b?.id != request.fighterBId ||
              state.policyKey != request.judgingPolicy) {
            throw StateError('Judging dependency changed');
          }
          request = PendingSubmission.fromJson({
            ...request.toJson(),
            'version': state.bout.version,
            'judging_revision': state.revision,
          });
        }
        await tx.update(
          'outbox',
          {'prepared_request': jsonEncode(request.toJson())},
          where: 'event_id=? AND state=?',
          whereArgs: [id, OutboxState.sending.name],
        );
        return OutboxEntry.fromRow({
          ...row,
          'prepared_request': jsonEncode(request.toJson()),
        });
      });

  Future<void> cancelUnsentJudge(String id) async => db.transaction((tx) async {
    final entry = OutboxEntry.fromRow(
      (await tx.query('outbox', where: 'event_id=?', whereArgs: [id])).single,
    );
    if (!entry.request.isJudge ||
        entry.dispatched ||
        ![
          OutboxState.pending,
          OutboxState.authentication,
          OutboxState.retryPaused,
        ].contains(entry.state)) {
      throw StateError('Organizer review required');
    }
    final rows = await tx.query(
      'outbox',
      where: 'origin=? AND bout_id=? AND seq>?',
      whereArgs: [entry.request.origin, entry.request.boutId, entry.sequence],
    );
    if (rows
        .map(OutboxEntry.fromRow)
        .any(
          (e) =>
              e.dependencies.contains(id) && e.state != OutboxState.cancelled,
        )) {
      throw StateError('Dependent actions exist');
    }
    await tx.update(
      'outbox',
      {
        'state': OutboxState.cancelled.name,
        'resolution': jsonEncode({'reason': 'CANCELLED_BEFORE_DISPATCH'}),
      },
      where: 'event_id=?',
      whereArgs: [id],
    );
  });

  Future<List<OutboxEntry>> entries({String? origin}) async => (await db.query(
    'outbox',
    where: origin == null ? null : 'origin=?',
    whereArgs: origin == null ? null : [origin],
    orderBy: 'seq',
  )).map(OutboxEntry.fromRow).toList();
  Future<OutboxEntry?> entry(String eventId) async {
    final rows = await db.query(
      'outbox',
      where: 'event_id=?',
      whereArgs: [eventId],
    );
    return rows.isEmpty ? null : OutboxEntry.fromRow(rows.single);
  }

  Future<int> unresolvedCount({String? origin}) async =>
      (await entries(origin: origin)).where((e) => e.unresolved).length;
  Future<bool> hasResult(String origin, String boutId) async => (await db.query(
    'outbox',
    columns: ['event_id'],
    where: "origin=? AND bout_id=? AND operation='result'",
    whereArgs: [origin, boutId],
    limit: 1,
  )).isNotEmpty;
  @override
  Future<PendingSubmission?> find(String clientEventId) async =>
      (await entry(clientEventId))?.request;
  @override
  Future<void> save(PendingSubmission submission) =>
      throw UnsupportedError('Use atomic confirm with a session');
  @override
  Future<void> setState(String id, SubmissionState state) =>
      throw UnsupportedError('Use fenced outbox transitions');
  Future<OutboxEntry?> claim(String origin, String owner, DateTime now) async =>
      db.transaction((tx) async {
        final millis = now.toUtc().millisecondsSinceEpoch,
            lease = (await tx.query('sync_lease')).single;
        if (lease['owner'] != null &&
            lease['owner'] != owner &&
            (lease['expires'] as int) > millis) {
          return null;
        }
        final rows = await tx.query(
          'outbox',
          where: 'origin=? AND state IN (?,?) AND next_attempt<=?',
          whereArgs: [
            origin,
            OutboxState.pending.name,
            OutboxState.sending.name,
            millis,
          ],
          orderBy: 'seq',
        );
        for (final row in rows) {
          final e = OutboxEntry.fromRow(row);
          var ready = true;
          for (final d in e.dependencies) {
            final dep = await tx.query(
              'outbox',
              columns: ['state'],
              where: 'event_id=?',
              whereArgs: [d],
            );
            if (dep.isEmpty ||
                dep.single['state'] != OutboxState.acknowledged.name) {
              ready = false;
            }
          }
          if (!ready) continue;
          await tx.update('sync_lease', {
            'owner': owner,
            'expires': millis + 120000,
          }, where: 'id=1');
          await tx.update(
            'outbox',
            {'state': OutboxState.sending.name, 'attempts': e.attempts + 1},
            where: 'event_id=?',
            whereArgs: [e.request.clientEventId],
          );
          return OutboxEntry.fromRow({
            ...row,
            'state': OutboxState.sending.name,
            'attempts': e.attempts + 1,
          });
        }
        return null;
      });
  Future<void> dispatched(String id, String owner) async =>
      db.transaction((tx) async {
        await _owns(tx, owner);
        await tx.rawUpdate(
          'UPDATE outbox SET dispatched=1 WHERE event_id=? AND state=?',
          [id, OutboxState.sending.name],
        );
      });
  Future<void> _owns(Transaction tx, String owner) async {
    if ((await tx.query('sync_lease')).single['owner'] != owner) {
      throw StateError('Sync lease lost');
    }
  }

  Future<void> finish(
    String id,
    String owner,
    OutboxState state, {
    String? code,
    TimerBout? current,
    Json? receipt,
    DateTime? next,
  }) async => db.transaction((tx) async {
    await _owns(tx, owner);
    await tx.update(
      'outbox',
      {
        'state': state.name,
        'error_code': code,
        'server_bout': current == null ? null : jsonEncode(current.toJson()),
        'receipt': receipt == null ? null : jsonEncode(receipt),
        'next_attempt': next?.toUtc().millisecondsSinceEpoch ?? 0,
      },
      where: 'event_id=? AND state=?',
      whereArgs: [id, OutboxState.sending.name],
    );
    if (state == OutboxState.acknowledged) {
      final row = (await tx.query(
        'outbox',
        where: 'event_id=?',
        whereArgs: [id],
      )).single;
      if (row['operation'] == 'judge') {
        final judging = JudgingReceipt.fromJson(receipt!).state;
        final key = 'judging|${row['origin']}|${row['bout_id']}';
        final cached = await tx.query(
          'cache',
          where: 'key=?',
          whereArgs: [key],
        );
        if (cached.isEmpty ||
            BigInt.parse(cached.single['revision'] as String) <=
                BigInt.parse(judging.bout.serverRevision)) {
          await tx.insert('cache', {
            'key': key,
            'body': jsonEncode(judging.toJson()),
            'revision': judging.bout.serverRevision,
            'saved_at': DateTime.parse(
              text(receipt['accepted_at']),
            ).millisecondsSinceEpoch,
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        }
      } else {
        await tx.update(
          'sessions',
          {'phase': 'ACKNOWLEDGED'},
          where: 'key=?',
          whereArgs: [
            sessionKey(row['origin'] as String, row['bout_id'] as String),
          ],
        );
      }
    }
    await tx.update('sync_lease', {'owner': null, 'expires': 0}, where: 'id=1');
  });
  Future<void> release(String owner) async => db
      .update(
        'sync_lease',
        {'owner': null, 'expires': 0},
        where: 'id=1 AND owner=?',
        whereArgs: [owner],
      )
      .then((_) {});
  Future<void> retryTransport(String origin) async => db
      .rawUpdate(
        "UPDATE outbox SET state=?, next_attempt=CASE WHEN error_code='RATE_LIMITED' THEN next_attempt ELSE 0 END WHERE origin=? AND state IN (?,?,?)",
        [
          OutboxState.pending.name,
          origin,
          OutboxState.pending.name,
          OutboxState.authentication.name,
          OutboxState.retryPaused.name,
        ],
      )
      .then((_) {});
  Future<void> handled(String id, String reason, DateTime now) async {
    if (reason.trim().isEmpty) throw ArgumentError('Review reason required');
    await db.transaction((tx) async {
      final row = (await tx.query(
        'outbox',
        where: 'event_id=?',
        whereArgs: [id],
      )).single;
      final entry = OutboxEntry.fromRow(row);
      var dependencyRefused = false;
      if (entry.state == OutboxState.pending) {
        for (final id in entry.dependencies) {
          final dependency = (await tx.query(
            'outbox',
            where: 'event_id=?',
            whereArgs: [id],
          )).single;
          if ([
            OutboxState.conflict.name,
            OutboxState.rejected.name,
            OutboxState.handled.name,
          ].contains(dependency['state'])) {
            dependencyRefused = true;
          }
        }
      }
      if (![
            OutboxState.conflict,
            OutboxState.rejected,
            OutboxState.authentication,
          ].contains(entry.state) &&
          !dependencyRefused) {
        throw StateError('Not a reviewable refusal');
      }
      await tx.update(
        'outbox',
        {
          'state': OutboxState.handled.name,
          'resolution': jsonEncode({
            'reason': reason.trim(),
            'handled_at': now.toUtc().toIso8601String(),
          }),
        },
        where: 'event_id=?',
        whereArgs: [id],
      );
    });
  }
}
