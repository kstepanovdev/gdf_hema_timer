// Opt-in synthetic loopback rehearsal. A local test harness acknowledges the
// START_NEXT_GROUP line via stdin after an explicit organizer START_GROUP.
// No organizer lifecycle command is sent by either Timer client.
import 'dart:convert';
import 'dart:io';
import 'package:gdf_hema_timer/modules/opossum/api_client.dart';
import 'package:gdf_hema_timer/modules/opossum/models.dart';
import 'package:gdf_hema_timer/modules/opossum/pending_submission.dart';

Future<void> main() async {
  final origin = Platform.environment['OPOSSUM_TEST_BASE_URL'],
      token = Platform.environment['OPOSSUM_TEST_TOKEN'],
      secondToken = Platform.environment['OPOSSUM_TEST_TOKEN_2'];
  if (origin == null || token == null || secondToken == null) {
    throw StateError('Synthetic test configuration required');
  }
  final config = ConnectionConfig(origin, token, allowLocalHttp: true);
  if (!['localhost', '127.0.0.1', '::1', '[::1]'].contains(config.baseUrl.host)) {
    throw StateError('Loopback only');
  }
  final clients = [
    HttpOpossumClient(config),
    HttpOpossumClient(
      ConnectionConfig(origin, secondToken, allowLocalHttp: true),
    ),
  ];
  final devices = [newRequestId(), newRequestId()];
  final saved = <String>{};
  void check(bool value, String message) {
    if (!value) throw StateError(message);
  }

  try {
    final nominations = await Future.wait(clients.map((c) => c.discover()));
    final nomination = nominations.first.singleWhere(
      (n) => n.tournamentName.startsWith('Synthetic Timer '),
    );
    check(
      nominations.last.any((n) => n.id == nomination.id),
      'Independent credential discovery',
    );
    final initial = await clients.first.worklist(nomination);
    check(initial.pistes.length == 2, 'Two physical pistes required');
    final pisteIds = initial.pistes.map((p) => p.id).toList();
    final firstGroups = initial.pistes
        .map((p) => p.assignments.first.groupId)
        .toSet();
    check(firstGroups.length == 2, 'Concurrent independent groups');
    final later = initial.groups.singleWhere(
      (g) => !firstGroups.contains(g.id),
    );
    check(
      initial.assignments
          .where((a) => a.groupId == later.id)
          .every((a) => a.items.every((i) => !i.selectable)),
      'Later group must wait',
    );
    final planned = initial.assignments
        .firstWhere((a) => a.groupId == later.id)
        .items
        .first;
    // Even a deliberately forged initial client snapshot cannot bypass domain start guards.
    Future<void> score(int device, TimerBout bout) async {
      final fresh = await clients[device].bout(bout.id);
      final local = fresh.toSession();
      final request = PendingSubmission.confirm(
        origin: config.baseUrl.toString(),
        bout: fresh,
        session: local.copyWith(
          a: local.a.copyWith(score: 5),
          b: local.b.copyWith(score: 1),
          leftIsA: device == 0,
        ),
        deviceId: devices[device],
      );
      final accepted = await clients[device].submit(request);
      check(accepted.boutId == fresh.id, 'Wrong bout accepted');
      check(saved.add(fresh.id), 'Duplicate pairing submitted');
    }

    final beforeRevision = initial.serverRevision;
    // Both devices read their next bout before either result is submitted.
    await Future.wait([
      for (var d = 0; d < 2; d++) score(d, initial.pistes[d].recommended!.bout),
    ]);
    check(
      (await clients.first.worklist(nomination)).serverRevision !=
          beforeRevision,
      'Accepted result must change revision',
    );
    Future<int> drainConfiguration(int d) async {
      var count = 0;
      for (var guard = 0; guard < 200; guard++) {
        final work = await clients[d].worklist(nomination);
        final item = work.piste(pisteIds[d])!.recommended;
        if (item == null) return count;
        await score(d, item.bout);
        count++;
      }
      throw StateError('Unexpected unbounded work');
    }

    await Future.wait([drainConfiguration(0), drainConfiguration(1)]);
    final waiting = await clients.first.worklist(nomination);
    check(
      waiting.pistes.every((p) => p.recommended == null),
      'Later group cannot self-start',
    );
    check(
      !(await clients.first.bout(planned.bout.id)).writable,
      'Later group remains non-writable',
    );
    stdout.writeln('START_NEXT_GROUP');
    final ack = await stdin
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .first;
    check(ack == 'STARTED', 'Organizer start acknowledgement required');
    final reused = await clients.first.worklist(nomination);
    check(
      reused.pistes.every((p) => p.assignments.first.groupId == later.id),
      'Same pistes must now serve later group',
    );
    final configurations = <String>{};
    for (var guard = 0; guard < 100; guard++) {
      final work = await clients.first.worklist(nomination);
      for (final c in work.configurations.where(
        (c) => c.groupId == later.id && c.status == 'ACTIVE',
      )) {
        configurations.add(c.id);
      }
      for (final a in work.assignments.where(
        (a) => a.configurationStatus == 'PLANNED',
      )) {
        check(
          a.items.every((i) => !i.selectable),
          'Future configuration wrongly writable',
        );
      }
      final ready = [
        for (var d = 0; d < 2; d++) work.piste(pisteIds[d])!.recommended,
      ];
      if (ready.every((i) => i == null)) break;
      await Future.wait([
        for (var d = 0; d < 2; d++)
          if (ready[d] != null) score(d, ready[d]!.bout),
      ]);
    }
    final finalWork = await clients.first.worklist(nomination);
    check(
      saved.length == 40,
      'All 6+6+28 source pairings must be accepted exactly once',
    );
    check(configurations.length > 1, 'Must execute multiple configurations');
    check(
      finalWork.configurations
          .where((c) => c.groupId == later.id)
          .every((c) => c.status == 'COMPLETED'),
      'All saved configurations completed',
    );
    check(
      finalWork.pistes.every((p) => p.recommended == null),
      'No work after completion',
    );
    stdout.writeln(
      'PASS: two authenticated Dart clients, 40 unique accepted bouts, independent groups, organizer-approved piste reuse, ${configurations.length} authoritative configurations; no client-generated pairings.',
    );
  } finally {
    for (final c in clients) {
      c.close();
    }
  }
}
