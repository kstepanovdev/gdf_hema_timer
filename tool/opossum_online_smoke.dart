// Opt-in, destructive-to-fixture smoke test. Never use a real tournament token.
// Only a loopback server and a tournament named "Synthetic Timer ..." qualify.
import 'dart:io';
import 'package:gdf_hema_timer/modules/opossum/api_client.dart';
import 'package:gdf_hema_timer/modules/opossum/pending_submission.dart';

Future<void> main() async {
  final origin = Platform.environment['OPOSSUM_TEST_BASE_URL'];
  final token = Platform.environment['OPOSSUM_TEST_TOKEN'];
  if (origin == null || token == null) {
    throw StateError('Provide synthetic loopback test configuration');
  }
  final config = ConnectionConfig(origin, token, allowLocalHttp: true);
  if (!['localhost', '127.0.0.1', '::1', '[::1]'].contains(config.baseUrl.host)) {
    throw StateError('Loopback test server only');
  }
  final api = HttpOpossumClient(config);
  try {
    final nomination = (await api.discover()).firstWhere(
      (n) => n.tournamentName.startsWith('Synthetic Timer '),
    );
    final work = await api.worklist(nomination);
    final item = work.assignments
        .expand((a) => a.items)
        .firstWhere((i) => i.selectable);
    final bout = await api.bout(item.bout.id);
    final local = bout.toSession();
    final swapped = local.copyWith(
      a: local.a.copyWith(score: 9),
      b: local.b.copyWith(score: 6),
      leftIsA: false,
    );
    final request = PendingSubmission.confirm(
      origin: config.baseUrl.toString(),
      bout: bout,
      session: swapped,
      deviceId: newRequestId(),
    );
    final accepted = await api.submit(request);
    final replay = await api.submit(request);
    final current = await api.bout(bout.id);
    final refreshed = await api.worklist(nomination);
    if (accepted.replayed != false ||
        replay.replayed != true ||
        current.scoreA != 9 ||
        current.scoreB != 6 ||
        current.status != 'COMPLETED' ||
        current.version != accepted.version ||
        refreshed.serverRevision == work.serverRevision) {
      throw StateError(
        'Authoritative acceptance/replay/refresh assertion failed',
      );
    }
    stdout.writeln(
      'PASS: authenticated discovery → fresh Round-Robin bout → A/B mapped NORMAL result → accepted → idempotent replay → authoritative bout/worklist refresh',
    );
    stdout.writeln(
      'Synthetic bout: ${bout.id}; version ${bout.version} → ${current.version}; revision ${work.serverRevision} → ${refreshed.serverRevision}',
    );
  } finally {
    api.close();
  }
}
