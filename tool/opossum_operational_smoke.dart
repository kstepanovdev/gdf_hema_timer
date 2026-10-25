// Synthetic loopback-only rehearsal using the real Timer API and durable outbox.
import 'dart:io';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:gdf_hema_timer/modules/opossum/api_client.dart';
import 'package:gdf_hema_timer/modules/opossum/models.dart';
import 'package:gdf_hema_timer/modules/opossum/outbox_sync.dart';
import 'package:gdf_hema_timer/modules/opossum/pending_submission.dart';
import 'package:gdf_hema_timer/modules/opossum/session_snapshot.dart';
import 'package:gdf_hema_timer/modules/opossum/tournament_store.dart';

Future<void> main(List<String> args) async {
  if (args.length != 1 ||
      !File(
        args[0],
      ).absolute.path.startsWith('${Directory.systemTemp.path}/')) {
    throw StateError(
      'Use a disposable SQLite file under the system temporary directory',
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
  final api = HttpOpossumClient(config),
      second = HttpOpossumClient(
        ConnectionConfig(
          config.baseUrl.toString(),
          Platform.environment['OPOSSUM_TEST_SECOND_TOKEN'] ?? '',
          allowLocalHttp: true,
        ),
      );
  sqfliteFfiInit();
  final store = await TournamentStore.open(databaseFactoryFfi, args[0]);
  final sync = OutboxSync(
    store: store,
    api: api,
    origin: config.baseUrl.toString(),
    credentialRef: credentialFingerprint(config.token),
  );
  try {
    final nomination = (await api.discover()).singleWhere(
      (n) => n.tournamentName.startsWith('Synthetic Timer '),
    );
    final work = await api.worklist(nomination);
    final first = work.operational.firstWhere((i) => i.selectable).bout;
    if ((await store.entries()).isNotEmpty) {
      throw StateError('Use an empty test outbox');
    }
    final competing = first.toSession();
    final stale = PendingSubmission.confirm(
      origin: config.baseUrl.toString(),
      bout: first,
      session: competing.copyWith(
        a: competing.a.copyWith(score: 8),
        b: competing.b.copyWith(score: 1),
      ),
      deviceId: '00000000-0000-4000-8000-000000000ffe',
    );
    var accepted = 0;
    Future<void> conduct(TimerBout bout) async {
      final local = bout.toSession();
      final snapshot = SessionSnapshot(
        origin: config.baseUrl.toString(),
        nomination: nomination,
        bout: bout,
        session: local.copyWith(
          a: local.a.copyWith(score: 7),
          b: local.b.copyWith(score: 2),
          leftIsA: false,
        ),
        remainingMs: 30000,
        configuredMs: 90000,
        wasRunning: false,
        events: [],
        savedAt: DateTime.now(),
      );
      final request = PendingSubmission.confirm(
        origin: snapshot.origin,
        bout: bout,
        session: snapshot.session,
        deviceId: '00000000-0000-4000-8000-000000000fff',
      );
      await store.confirm(
        request,
        snapshot,
        credentialFingerprint(config.token),
      );
      await sync.flush();
      final e = (await store.entry(request.clientEventId))!;
      if (e.state != OutboxState.acknowledged) {
        throw StateError(
          'Expected acknowledgement, got ${e.state}: ${e.errorCode}',
        );
      }
      if (e.receipt!['score_a'] != 7 || e.receipt!['score_b'] != 2) {
        throw StateError('Score orientation changed');
      }
      accepted++;
    }

    await conduct(first);
    try {
      await second.submit(stale);
      throw StateError('Second device overwrote an accepted result');
    } on OpossumException catch (e) {
      if (e.kind != ApiFailure.conflict) rethrow;
    }
    for (var step = 0; step < 32; step++) {
      final next = await api.worklist(nomination);
      final ready = next.operational.where((i) => i.selectable).firstOrNull;
      if (ready == null) {
        if (next.operational.any((i) => i.bout.status == 'SCHEDULED')) {
          throw StateError('Blocked competition remains');
        }
        stdout.writeln(
          '$accepted authoritative operational results acknowledged through SQLite; second device received conflict.',
        );
        return;
      }
      await conduct(await api.bout(ready.bout.id));
    }
    throw StateError('Synthetic work did not terminate');
  } finally {
    sync.dispose();
    api.close();
    second.close();
    await store.close();
  }
}
