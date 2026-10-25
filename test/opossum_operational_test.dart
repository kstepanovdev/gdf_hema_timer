import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:gdf_hema_timer/l10n/gen/app_localizations.dart';
import 'package:gdf_hema_timer/modules/bout_session/bout_session_controller.dart';
import 'package:gdf_hema_timer/modules/bout_session/bout_session.dart';
import 'package:gdf_hema_timer/modules/opossum/api_client.dart';
import 'package:gdf_hema_timer/modules/opossum/models.dart';
import 'package:gdf_hema_timer/modules/opossum/outbox_sync.dart';
import 'package:gdf_hema_timer/modules/opossum/pending_submission.dart';
import 'package:gdf_hema_timer/modules/opossum/session_snapshot.dart';
import 'package:gdf_hema_timer/modules/opossum/tournament_store.dart';
import 'package:gdf_hema_timer/modules/opossum/worklist_controller.dart';
import 'package:gdf_hema_timer/pages/opossum_worklist_page.dart';
import 'package:gdf_hema_timer/pages/score_page.dart';
import 'support/opossum_fixture.dart';

Json source(String key) => clone(
  object(
    object(
      jsonDecode(
        File('test/fixtures/opossum_operational_v1.json').readAsStringSync(),
      ),
    )[key],
  ),
);
TimerWorklist work(String key) => TimerWorklist.fromJson(source(key));
final nomination = NominationRef.fromJson(
  object(array(object(fixture()['discovery'])['nominations']).first),
);

class OperationalServer extends FakeTimerServer {
  OperationalServer(String key) : workJson = source(key) {
    current = clone(
      object(object(array(workJson['operational_bouts']).first)['bout']),
    );
  }
  final Json workJson;
  @override
  Future<http.Response> handle(http.Request request) async {
    if (request.method == 'GET' && request.url.path.endsWith('/worklist')) {
      if (request.headers['authorization'] != 'Bearer $syntheticToken') {
        return refusal(401, 'UNAUTHENTICATED');
      }
      if (failReads) return refusal(503, 'UNAVAILABLE');
      final j = clone(workJson);
      j['tournament_revision'] = current['tournament_revision'];
      for (final p in array(j['piste_worklists'])) {
        object(p)['tournament_revision'] = current['tournament_revision'];
      }
      for (final i in array(j['operational_bouts'])) {
        if (object(object(i)['bout'])['bout_id'] == current['bout_id']) {
          object(i)['bout'] = clone(current);
          object(i)['readiness'] = current['status'] == 'COMPLETED'
              ? 'COMPLETED'
              : 'READY';
        }
      }
      return response(j);
    }
    return super.handle(request);
  }
}

HttpOpossumClient client(OperationalServer s) => HttpOpossumClient(
  ConnectionConfig('https://example.test', syntheticToken),
  client: s.client(),
  timeout: const Duration(milliseconds: 100),
  readRetries: 0,
);

void main() {
  sqfliteFfiInit();
  test(
    'null group/piste elimination selection and resolved routes use real Opossum snapshots',
    () async {
      final api = client(OperationalServer('no_pistes')),
          c = WorklistController(
            api: client(OperationalServer('no_pistes')),
            nomination: nomination,
          );
      addTearDown(api.close);
      addTearDown(c.api.close);
      addTearDown(c.dispose);
      await c.refresh();
      expect(c.work!.pistes, isEmpty);
      expect(c.work!.operational, hasLength(2));
      final initial = c.work!.operational.first.bout;
      expect(initial.groupId, isNull);
      expect(initial.pisteId, isNull);
      expect(c.begin(initial), isTrue);
      expect(c.begin(c.work!.operational.last.bout), isFalse);
      final medals = work('medals');
      expect(
        medals.operational
            .where((i) => i.bout.bracketRole == 'BRONZE')
            .single
            .selectable,
        isTrue,
      );
      expect(
        medals.operational
            .where((i) => i.bout.bracketRole == 'FINAL')
            .single
            .bout
            .blockingCode,
        'BRONZE_FIRST',
      );
      expect(
        medals.operational
            .where((i) => i.bout.bracketRole == 'FINAL')
            .single
            .selectable,
        isFalse,
      );
      expect(
        work('gold').operational
            .where((i) => i.bout.bracketRole == 'FINAL')
            .single
            .selectable,
        isTrue,
      );
    },
  );
  for (final key in [
    'group_refight',
    'group_pool',
    'stage_refight',
    'stage_pool',
  ]) {
    test(
      '$key is a distinct supported tie-break with immutable round identity',
      () {
        final w = work(key), b = w.operational.first.bout;
        expect(b.purpose, 'TIE_BREAK');
        expect(b.tieBreakRoundId, isNotNull);
        expect(b.tieBreakSequence, 1);
        expect(b.pisteId, isNull);
        expect(b.writable, isTrue);
        expect(b.groupId, key.startsWith('stage') ? isNull : isNotNull);
        if (key.startsWith('stage')) expect(b.stageStatus, 'COMPLETED');
        final local = b.toSession();
        final request = PendingSubmission.confirm(
          origin: 'https://example.test',
          bout: b,
          session: local.copyWith(
            a: local.a.copyWith(score: 5),
            b: local.b.copyWith(score: 1),
          ),
          deviceId: deviceId,
        );
        expect(request.body['expected_pairing'], {
          'fighter_a_id': b.a!.id,
          'fighter_b_id': b.b!.id,
        });
        expect(request.body['result_type'], 'NORMAL');
        expect(w.bout(b.id)!.id, b.id);
      },
    );
  }
  test(
    'equal elimination and invalid sudden-death scores rejected, visual swap preserves A/B',
    () {
      final b = work('initial').operational.first.bout;
      final c = BoutSessionController(initialSession: b.toSession());
      addTearDown(c.dispose);
      expect(
        () => PendingSubmission.confirm(
          origin: 'https://example.test',
          bout: b,
          session: c.session,
          deviceId: deviceId,
        ),
        throwsFormatException,
      );
      c.setScore(DisplaySide.left, 7);
      c.setScore(DisplaySide.right, 2);
      c.swapSides();
      final request = PendingSubmission.confirm(
        origin: 'https://example.test',
        bout: b,
        session: c.session,
        deviceId: deviceId,
      );
      expect([request.scoreA, request.scoreB], [7, 2]);
      final raw = b.toJson();
      object(raw['mutual_hits'])['phase'] = 'SUDDEN_DEATH';
      final sudden = TimerBout.fromJson(raw);
      expect(
        () => PendingSubmission.confirm(
          origin: 'https://example.test',
          bout: sudden,
          session: c.session,
          deviceId: deviceId,
        ),
        throwsFormatException,
      );
      expect(
        PendingSubmission.confirm(
          origin: 'https://example.test',
          bout: sudden,
          session: c.session.copyWith(
            a: c.session.a.copyWith(score: 1),
            b: c.session.b.copyWith(score: 0),
          ),
          deviceId: deviceId,
        ).scoreA,
        1,
      );
    },
  );
  test('AUTO WIN is visible but never a numeric timer result', () {
    final i = work(
      'withdrawal',
    ).operational.firstWhere((i) => i.bout.resultType == 'AUTO_WIN');
    expect(i.selectable, isFalse);
    expect(i.bout.scoreA, isNull);
    expect(i.bout.scoreB, isNull);
    expect(
      () => PendingSubmission.confirm(
        origin: 'https://example.test',
        bout: i.bout,
        session: i.bout.toSession(),
        deviceId: deviceId,
      ),
      throwsFormatException,
    );
  });
  test(
    'legacy nomination unassigned list works without the additive operational field',
    () {
      final j = source('initial')..remove('operational_bouts');
      expect(TimerWorklist.fromJson(j).operational, hasLength(2));
    },
  );
  test('foreign, duplicate and wrong-stage operational items fail closed', () {
    for (final mutate in <void Function(Json)>[
      (b) => b['nomination_id'] = '00000000-0000-4000-8000-000000000999',
      (b) => b['stage_id'] = '00000000-0000-4000-8000-000000000999',
      (b) => b['group_id'] = '00000000-0000-4000-8000-000000000999',
    ]) {
      final j = source('initial');
      mutate(object(object(array(j['operational_bouts']).first)['bout']));
      expect(() => TimerWorklist.fromJson(j), throwsFormatException);
    }
    final j = source('initial');
    array(
      j['operational_bouts'],
    ).add(clone(object(array(j['operational_bouts']).first)));
    expect(() => TimerWorklist.fromJson(j), throwsFormatException);
  });
  for (final change in ['completed', 'pairing']) {
    test(
      'durable offline $change conflict retains the original elimination evidence after restart',
      () async {
        final dir = await Directory.systemTemp.createTemp('timer-operational-');
        var store = await TournamentStore.open(
          databaseFactoryFfi,
          '${dir.path}/test.sqlite',
        );
        final server = OperationalServer('no_pistes'),
            api = client(server),
            b = TimerBout.fromJson(server.current),
            credential = credentialFingerprint(syntheticToken),
            session = b.toSession();
        final snapshot = SessionSnapshot(
          origin: 'https://example.test',
          nomination: nomination,
          bout: b,
          session: session.copyWith(
            a: session.a.copyWith(score: 7),
            b: session.b.copyWith(score: 2),
          ),
          remainingMs: 40000,
          configuredMs: 90000,
          wasRunning: false,
          events: [],
          savedAt: DateTime.now(),
        );
        final r = PendingSubmission.confirm(
          origin: snapshot.origin,
          bout: b,
          session: snapshot.session,
          deviceId: deviceId,
        );
        await store.confirm(r, snapshot, credential);
        await store.close();
        if (change == 'completed') {
          server.current['entity_version'] = b.version + 1;
          server.current['status'] = 'COMPLETED';
        } else {
          server.current['fighter_a'] = clone(
            object(server.current['fighter_b']),
          );
        }
        store = await TournamentStore.open(
          databaseFactoryFfi,
          '${dir.path}/test.sqlite',
        );
        final sync = OutboxSync(
          store: store,
          api: api,
          origin: snapshot.origin,
          credentialRef: credential,
        );
        await sync.flush();
        final entry = (await store.entries()).single;
        expect(entry.state, OutboxState.conflict);
        expect(entry.request.toJson(), r.toJson());
        expect(server.writes, isEmpty);
        expect(entry.snapshot.session.a.score, 7);
        sync.dispose();
        api.close();
        await store.close();
        await dir.delete(recursive: true);
      },
    );
  }
  testWidgets(
    'no-piste selection warns, opens an actual elimination bout, and retains it on return',
    (tester) async {
      SharedPreferences.setMockInitialValues({'show_help_on_launch': false});
      tester.view.physicalSize = const Size(1000, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final api = client(OperationalServer('no_pistes'));
      addTearDown(api.close);
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: OpossumWorklistPage(
            api: api,
            nomination: nomination,
            origin: 'https://example.test',
            deviceId: deviceId,
            repository: MemoryPendingSubmissionRepository(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Elimination & tie-break bouts'), findsOneWidget);
      final b = work('no_pistes').operational.first.bout;
      final row = find.byKey(ValueKey('operational-${b.id}'));
      await tester.ensureVisible(row);
      await tester.tap(row);
      await tester.pumpAndSettle();
      expect(find.text('Select an unreserved bout?'), findsOneWidget);
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<ScorePage>(find.byType(ScorePage)).controller!.session.id,
        b.id,
      );
      expect(find.textContaining('Semifinal'), findsWidgets);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );
}
