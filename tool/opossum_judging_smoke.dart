// Synthetic loopback-only API/SQLite judging rehearsal. Never use real tournaments.
import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:gdf_hema_timer/modules/opossum/api_client.dart';
import 'package:gdf_hema_timer/modules/opossum/judging.dart';
import 'package:gdf_hema_timer/modules/opossum/outbox_sync.dart';
import 'package:gdf_hema_timer/modules/opossum/pending_submission.dart';
import 'package:gdf_hema_timer/modules/opossum/session_snapshot.dart';
import 'package:gdf_hema_timer/modules/opossum/tournament_store.dart';

class LoseJudgeAcknowledgement extends http.BaseClient {
  final http.Client inner = http.Client();
  bool lost = false;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final response = await inner.send(request);
    if (!lost &&
        request.method == 'POST' &&
        request.url.path.endsWith('/judge-events') &&
        response.statusCode == 200) {
      lost = true;
      await response.stream.drain<void>();
      return Completer<http.StreamedResponse>().future;
    }
    return response;
  }

  @override
  void close() => inner.close();
}

Future<void> main(List<String> args) async {
  if (args.length != 2 ||
      !['write', 'recover'].contains(args[0]) ||
      !File(args[1]).absolute.path.startsWith('${Directory.systemTemp.path}/')) {
    throw StateError(
      'Use write/recover and a disposable temporary SQLite file',
    );
  }
  final config = ConnectionConfig(
    Platform.environment['OPOSSUM_TEST_BASE_URL'] ?? '',
    Platform.environment['OPOSSUM_TEST_TOKEN'] ?? '',
    allowLocalHttp: true,
  );
  if (!['localhost', '127.0.0.1', '::1', '[::1]'].contains(config.baseUrl.host)) {
    throw StateError('Synthetic loopback server only');
  }
  final loss = LoseJudgeAcknowledgement();
  final api = HttpOpossumClient(
    config,
    client: args[0] == 'write' ? loss : null,
    timeout: const Duration(seconds: 2),
    readRetries: 0,
  );
  sqfliteFfiInit();
  final store = await TournamentStore.open(databaseFactoryFfi, args[1]);
  final sync = OutboxSync(
    store: store,
    api: api,
    origin: config.baseUrl.toString(),
    credentialRef: credentialFingerprint(config.token),
  );
  if (args[0] == 'write') {
    if ((await store.entries()).isNotEmpty) {
      throw StateError('Use an empty synthetic queue');
    }
    final n = (await api.discover()).singleWhere(
      (n) => n.tournamentName.startsWith('Synthetic Timer '),
    );
    final work = await api.worklist(n);
    final bout = work.assignments
        .expand((a) => a.items)
        .firstWhere((i) => i.selectable)
        .bout;
    final judging = await api.judging(bout.id), local = bout.toSession();
    final snapshot = SessionSnapshot(
      origin: config.baseUrl.toString(),
      nomination: n,
      bout: bout,
      session: local.copyWith(
        a: local.a.copyWith(score: 7),
        b: local.b.copyWith(score: 4),
      ),
      remainingMs: 45000,
      configuredMs: 90000,
      wasRunning: false,
      events: [],
      savedAt: DateTime.now(),
    );
    for (var i = 0; i < 3; i++) {
      final event = PendingSubmission.judge(
        origin: snapshot.origin,
        judging: judging,
        session: snapshot.session,
        kind: JudgeEventKind.mutualHit,
        deviceId: '00000000-0000-4000-8000-000000000fff',
      );
      await store.confirmJudge(
        event,
        snapshot,
        credentialFingerprint(config.token),
      );
    }
    await sync.flush();
    if (!loss.lost ||
        (await store.entries()).any((e) => e.state == OutboxState.acknowledged)) {
      throw StateError(
        'Expected a lost accepted receipt and retained dependent operations',
      );
    }
    stdout.writeln(
      'Three durable judge intents retained after an accepted response was lost.',
    );
    // Deliberately terminate without closing SQLite, as in process death.
    exit(0);
  }
  await sync.retry();
  final entries = await store.entries();
  if (entries.length != 3 ||
      entries.any((e) => e.state != OutboxState.acknowledged)) {
    throw StateError('Judging recovery did not complete');
  }
  final state = await api.judging(entries.first.request.boutId);
  if (state.bout.resultType != 'DOUBLE_LOSS' ||
      state.bout.effectiveHits != 3 ||
      state.records
              .where((r) => r['type'] == 'MUTUAL_HIT' && r['voided_at'] == null)
              .length !=
          3 ||
      state.bout.scoreA != 7 ||
      state.bout.scoreB != 4) {
    throw StateError('Authoritative recovery mismatch');
  }
  if (entries.any((e) => !e.request.isJudge)) {
    throw StateError('Competing result submission');
  }
  stdout.writeln(
    'Recovered the original event identity, acknowledged three unique records, and verified server Double Loss 7:4 without a competing result.',
  );
  await sync.shutdown();
  api.close();
  await store.close();
  loss.close();
}
