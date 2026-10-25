// Opt-in real PostgreSQL/API/SQLite rehearsal. Synthetic loopback setup only.
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:gdf_hema_timer/modules/opossum/api_client.dart';
import 'package:gdf_hema_timer/modules/opossum/pairing.dart';
import 'package:gdf_hema_timer/modules/opossum/pending_submission.dart';
import 'package:gdf_hema_timer/modules/opossum/session_snapshot.dart';
import 'package:gdf_hema_timer/modules/opossum/tournament_store.dart';
import 'package:gdf_hema_timer/modules/opossum/outbox_sync.dart';

Future<void> main(List<String> args) async {
  if (args.length != 2 ||
      args.any(
        (p) =>
            !File(p).absolute.path.startsWith('${Directory.systemTemp.path}/'),
      )) {
    throw StateError('Use disposable setup JSON and SQLite paths under /tmp');
  }
  final setup =
      jsonDecode(await File(args[0]).readAsString()) as Map<String, dynamic>;
  final origin = Uri.parse(setup['base'] as String);
  if (origin.scheme != 'http' || origin.host != '127.0.0.1') {
    throw StateError('Synthetic loopback only');
  }
  final prefix = setup['prefix'] as String;
  if (!RegExp(r'^/api/v1/tournaments/[0-9a-f-]{36}$').hasMatch(prefix)) {
    throw StateError('Invalid synthetic organizer path');
  }
  final links = (setup['links'] as List)
      .cast<String>()
      .map((value) => PairingLink.parse(value, allowLocalHttp: true))
      .toList();
  if (links.length != 2 || links.any((link) => link.origin != origin)) {
    throw StateError('Pairings must use the same synthetic loopback server');
  }
  final transport = HttpPairingTransport();
  final deviceId = newRequestId();
  final first = await transport.exchange(links[0], deviceId);
  final api = HttpOpossumClient(first.config);
  try {
    if ((await api.identity())?.id != first.identity.id) {
      throw StateError('Identity mismatch');
    }
    try {
      await transport.exchange(links[0], deviceId);
      throw StateError('Pairing reused');
    } on OpossumException catch (e) {
      if (e.code != 'PAIRING_CODE_INVALID') rethrow;
    }
    final nomination = (await api.discover()).singleWhere(
      (n) => n.tournamentName.startsWith('Synthetic Timer '),
    );
    // A separate process loses a real accepted response; another recovers its original key.
    for (final mode in ['write', 'recover']) {
      final result = await Process.run(
        Platform.resolvedExecutable,
        ['run', 'tool/opossum_offline_smoke.dart', mode, args[1]],
        environment: {
          ...Platform.environment,
          'OPOSSUM_TEST_BASE_URL': first.config.baseUrl.toString(),
          'OPOSSUM_TEST_TOKEN': first.config.token,
        },
      );
      if (result.exitCode != 0) {
        throw StateError('Offline process failed: ${result.stderr}');
      }
      stdout.write(result.stdout);
    }
    sqfliteFfiInit();
    var store = await TournamentStore.open(databaseFactoryFfi, args[1]);
    final work = await api.worklist(nomination);
    final bout = work.assignments
        .expand((a) => a.items)
        .firstWhere((i) => i.selectable)
        .bout;
    final local = bout.toSession();
    final session = local.copyWith(
      a: local.a.copyWith(score: 8),
      b: local.b.copyWith(score: 3),
    );
    final snapshot = SessionSnapshot(
      origin: first.config.baseUrl.toString(),
      nomination: nomination,
      bout: bout,
      session: session,
      remainingMs: 45000,
      configuredMs: 90000,
      wasRunning: false,
      events: [],
      savedAt: DateTime.now().toUtc(),
    );
    final pending = PendingSubmission.confirm(
      origin: snapshot.origin,
      bout: bout,
      session: session,
      deviceId: deviceId,
    );
    await store.confirm(
      pending,
      snapshot,
      credentialFingerprint(first.config.token),
    );
    await store.close();
    final response = await http.post(
      origin.resolve('$prefix/timer-clients/${first.identity.id}/revoke'),
      headers: (setup['organizerHeaders'] as Map).cast<String, String>(),
    );
    if (response.statusCode != 200) throw StateError('Revocation failed');
    try {
      await api.identity();
      throw StateError('Revoked token accepted');
    } on OpossumException catch (e) {
      if (e.kind != ApiFailure.authentication) rethrow;
    }
    final second = await transport.exchange(links[1], deviceId);
    final replacement = HttpOpossumClient(second.config);
    store = await TournamentStore.open(databaseFactoryFfi, args[1]);
    final sender = OutboxSync(
      store: store,
      api: replacement,
      origin: snapshot.origin,
      credentialRef: credentialFingerprint(second.config.token),
    );
    await sender.retry();
    final evidence = (await store.entries()).singleWhere(
      (e) => e.request.idempotencyKey == pending.idempotencyKey,
    );
    if (evidence.errorCode != 'CREDENTIAL_CHANGED' ||
        evidence.state != OutboxState.authentication ||
        evidence.request.body.toString() != pending.body.toString()) {
      throw StateError('Re-pair lost or transplanted pending evidence');
    }
    if ((await replacement.bout(bout.id)).status != 'SCHEDULED' ||
        (await replacement.worklist(nomination)).assignments.isEmpty) {
      throw StateError('Replacement changed sporting work');
    }
    sender.dispose();
    replacement.close();
    await store.close();
    stdout.writeln(
      'PASS: real QR exchange → identity/worklist → single-use rejection → process-restart idempotent recovery → revocation → re-pair → unchanged durable pending evidence, no unauthorized replay.',
    );
  } finally {
    api.close();
    transport.close();
  }
}
