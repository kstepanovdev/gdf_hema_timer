// Real API + SQLite process-restart rehearsal. Synthetic loopback servers only.
import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:gdf_hema_timer/modules/opossum/api_client.dart';
import 'package:gdf_hema_timer/modules/opossum/outbox_sync.dart';
import 'package:gdf_hema_timer/modules/opossum/pending_submission.dart';
import 'package:gdf_hema_timer/modules/opossum/session_snapshot.dart';
import 'package:gdf_hema_timer/modules/opossum/tournament_store.dart';

class LoseAcceptedResponse extends http.BaseClient {
  final http.Client inner = http.Client();
  bool lost = false;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final response = await inner.send(request);
    if (!lost && request.method == 'PUT' && response.statusCode == 200) {
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
      !File(
        args[1],
      ).absolute.path.startsWith('${Directory.systemTemp.path}/')) {
    throw StateError('Use a synthetic temporary SQLite file');
  }
  final config = ConnectionConfig(
    Platform.environment['OPOSSUM_TEST_BASE_URL'] ?? '',
    Platform.environment['OPOSSUM_TEST_TOKEN'] ?? '',
    allowLocalHttp: true,
  );
  if (![
    'localhost',
    '127.0.0.1',
    '::1',
    '[::1]',
  ].contains(config.baseUrl.host)) {
    throw StateError('Synthetic loopback server only');
  }
  final loss = LoseAcceptedResponse(),
      api = HttpOpossumClient(
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
    final n = (await api.discover()).singleWhere(
      (n) => n.tournamentName.startsWith('Synthetic Timer '),
    );
    final work = await api.worklist(n),
        bout = (await api.worklist(n)).assignments
            .expand((a) => a.items)
            .firstWhere((i) => i.selectable)
            .bout;
    final local = bout.toSession();
    final session = local.copyWith(
      a: local.a.copyWith(score: 7),
      b: local.b.copyWith(score: 2),
      leftIsA: false,
    );
    final snapshot = SessionSnapshot(
      origin: config.baseUrl.toString(),
      nomination: n,
      bout: bout,
      session: session,
      remainingMs: 45000,
      configuredMs: 90000,
      wasRunning: false,
      events: [],
      savedAt: DateTime.now().toUtc(),
    );
    final request = PendingSubmission.confirm(
      origin: snapshot.origin,
      bout: bout,
      session: session,
      deviceId: newRequestId(),
    );
    await store.confirm(request, snapshot, credentialFingerprint(config.token));
    await sync.flush();
    final entry = (await store.entries()).single;
    if (!loss.lost ||
        entry.state != OutboxState.pending ||
        !entry.dispatched ||
        work.serverRevision == (await api.worklist(n)).serverRevision) {
      throw StateError('Expected a real accepted-but-timed-out submission');
    }
    stdout.writeln(
      'PASS: actual server accepted 7:2; response lost; original request is durably pending.',
    );
    exit(0); // No close/checkpoint: the next process must recover SQLite.
  }
  if (args[0] != 'recover') throw StateError('Use write or recover');
  final before = (await store.entries()).single;
  if (!before.snapshot.nomination.tournamentName.startsWith(
    'Synthetic Timer ',
  )) {
    throw StateError('Synthetic data only');
  }
  await sync.retry();
  final after = (await store.entries()).single;
  if (after.state != OutboxState.acknowledged ||
      after.receipt?['replayed'] != true ||
      before.request.idempotencyKey != after.request.idempotencyKey) {
    throw StateError('Idempotent recovery failed');
  }
  final bout = await api.bout(after.request.boutId);
  if (bout.scoreA != 7 ||
      bout.scoreB != 2 ||
      bout.version != after.receipt!['entity_version']) {
    throw StateError('Stored authoritative result mismatch');
  }
  stdout.writeln(
    'PASS: separate process recovered original request; Opossum replayed its acknowledgement; no second mutation or overwrite.',
  );
  sync.dispose();
  api.close();
  await store.close();
}
