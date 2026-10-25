// Synthetic process-death persistence probe. Used by the recovery tests.
import 'dart:convert';
import 'dart:io';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:gdf_hema_timer/modules/opossum/models.dart';
import 'package:gdf_hema_timer/modules/opossum/pending_submission.dart';
import 'package:gdf_hema_timer/modules/opossum/session_snapshot.dart';
import 'package:gdf_hema_timer/modules/opossum/tournament_store.dart';

Future<void> main(List<String> args) async {
  if (args.length != 3 ||
      !File(
        args[1],
      ).absolute.path.startsWith('${Directory.systemTemp.path}/')) {
    throw StateError('Synthetic temporary database only');
  }
  final snapshot = SessionSnapshot.fromJson(
    object(jsonDecode(File(args[2]).readAsStringSync())),
  );
  if (!snapshot.nomination.tournamentName.startsWith('Synthetic Timer ')) {
    throw StateError('Synthetic tournament only');
  }
  sqfliteFfiInit();
  final store = await TournamentStore.open(databaseFactoryFfi, args[1]);
  if (args[0] == 'write') {
    final request = PendingSubmission.confirm(
      origin: snapshot.origin,
      bout: snapshot.bout,
      session: snapshot.session,
      deviceId: '00000000-0000-4000-8000-000000000fff',
    );
    await store.confirm(request, snapshot, 'synthetic-fingerprint');
    stdout.writeln(request.clientEventId);
    // Deliberately do not close/checkpoint SQLite: the transaction alone must
    // survive process termination and subsequent WAL recovery.
    exit(0);
  }
  if (args[0] != 'read') throw StateError('Unsupported probe operation');
  final entry = (await store.entries()).single;
  stdout.writeln(
    jsonEncode({
      'event_id': entry.request.clientEventId,
      'state': entry.state.name,
      'score_a': entry.request.scoreA,
      'remaining_ms': entry.snapshot.remainingMs,
      'was_running': entry.snapshot.wasRunning,
    }),
  );
  await store.close();
}
