import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gdf_hema_timer/l10n/gen/app_localizations.dart';
import 'package:gdf_hema_timer/modules/bout_session/bout_session_controller.dart';
import 'package:gdf_hema_timer/modules/opossum/api_client.dart';
import 'package:gdf_hema_timer/modules/opossum/models.dart';
import 'package:gdf_hema_timer/modules/opossum/pending_submission.dart';
import 'package:gdf_hema_timer/modules/opossum/worklist_controller.dart';
import 'package:gdf_hema_timer/pages/opossum_worklist_page.dart';
import 'package:gdf_hema_timer/pages/score_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'support/opossum_fixture.dart';

final scenarios = object(
  jsonDecode(
    utf8.decode(
      gzip.decode(
        File('test/fixtures/opossum_execution_v1.json.gz').readAsBytesSync(),
      ),
    ),
  ),
);
TimerWorklist snapshot(String key) =>
    TimerWorklist.fromJson(object(scenarios[key]));
NominationRef get nomination => NominationRef.fromJson(
  object(array(object(fixture()['discovery'])['nominations']).first),
);

class SnapshotClient implements OpossumClient {
  TimerWorklist current = snapshot('initial');
  TimerBout? overrideBout;
  Completer<TimerWorklist>? gate;
  int reads = 0;
  bool unavailable = false;
  @override
  Future<TimerWorklist> worklist(NominationRef n) async {
    reads++;
    if (unavailable) throw const OpossumException(ApiFailure.unavailable);
    return gate?.future ?? Future.value(current);
  }

  @override
  Future<TimerBout> bout(String id) async => overrideBout ?? current.bout(id)!;
  @override
  Future<List<NominationRef>> discover() async => [nomination];
  @override
  Future<AcceptedResult> submit(PendingSubmission request) =>
      throw StateError('read-only fixture client');
  @override
  void close() {}
}

Widget app(Widget child, {String locale = 'en'}) => MaterialApp(
  locale: Locale(locale),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: child,
);
Widget page(SnapshotClient api) => OpossumWorklistPage(
  api: api,
  nomination: nomination,
  origin: 'https://example.test',
  deviceId: deviceId,
  repository: MemoryPendingSubmissionRepository(),
);
void main() {
  test(
    'two independent groups share one wave; later group has both physical allocations',
    () {
      final w = snapshot('initial');
      expect(w.pistes, hasLength(2));
      expect(w.waves.map((w) => w.order), [1, 2]);
      expect(w.allocations.map((a) => a.pisteIds.length), [1, 1, 2]);
      final seen = <String>{};
      for (final p in w.pistes) {
        expect(p.assignments.first.group.status, 'STARTED');
        expect(p.recommended, isNotNull);
        for (final a in p.assignments) {
          for (final i in a.items) {
            expect(seen.add(i.bout.id), isTrue);
            expect(i.bout.pisteId, p.id);
            expect(i.bout.groupId, a.groupId);
            expect(i.orderKey, hasLength(4));
          }
          if (a.wave!.order == 2) {
            expect(a.group.status, 'GENERATED');
            expect(a.items.every((i) => !i.selectable), isTrue);
            expect(
              a.items.every((i) => i.bout.blockingCode == 'START_GROUP'),
              isTrue,
            );
          }
        }
      }
      expect(seen, hasLength(6 + 6 + 28));
    },
  );
  for (final raw in array(scenarios['sizes'])) {
    final j = object(raw),
        n = integer(j['participants']),
        p = integer(j['pistes']);
    test(
      '$n fighters / $p pistes retain all authoritative pairs and active-configuration writability',
      () {
        final before = TimerWorklist.fromJson(object(j['before'])),
            after = TimerWorklist.fromJson(object(j['after']));
        final items = before.assignments.expand((a) => a.items).toList();
        expect(items, hasLength(n * (n - 1) ~/ 2));
        expect(
          items.map((i) => i.bout.id).toSet(),
          array(j['source_bout_ids']).toSet(),
        );
        expect(
          items
              .map((i) => ([i.bout.a!.id, i.bout.b!.id]..sort()).join(':'))
              .toSet(),
          hasLength(items.length),
        );
        final active = before.configurations.singleWhere(
          (c) => c.status == 'ACTIVE',
        );
        for (final a in before.assignments) {
          for (final i in a.items) {
            expect(i.selectable, a.configurationId == active.id);
          }
        }
        expect(
          after.configurations.singleWhere((c) => c.id == active.id).status,
          'COMPLETED',
        );
        expect(
          after.configurations
              .singleWhere((c) => c.status == 'ACTIVE')
              .sequence,
          2,
        );
        expect(
          after.assignments.every((a) => a.configurationId != active.id),
          isTrue,
        );
        expect(before.assignments.any((a) => a.movesAfter.isNotEmpty), isTrue);
        for (final a in before.assignments) {
          final next = before.configurations
              .where((c) => c.sequence == (a.configurationSequence ?? 0) + 1)
              .firstOrNull;
          if (next != null) {
            expect(
              a.nextPopulation!.map((f) => f.id).toList(),
              next.populations[a.pisteId],
            );
          }
        }
      },
    );
  }
  test(
    'generated group cannot start itself; stage remains a waiting state',
    () {
      final w = snapshot('unstarted');
      expect(
        w.assignments
            .expand((a) => a.items)
            .every(
              (i) => !i.selectable && i.bout.blockingCode == 'START_STAGE',
            ),
        isTrue,
      );
      expect(w.pistes.every((p) => p.recommended == null), isTrue);
    },
  );
  test('recommendation is not a prohibition for another READY bout', () async {
    final api = SnapshotClient(),
        c = WorklistController(api: SnapshotClient(), nomination: nomination);
    addTearDown(c.dispose);
    await c.refresh();
    final last = api.current.pistes.first.assignments.first.items.last;
    expect(last.bout.id, isNot(c.selected!.recommendedBoutId));
    expect(last.selectable, isTrue);
    expect(c.begin(last.bout), isTrue);
  });
  test(
    'independent devices retain piste through wave reuse and never share local session state',
    () async {
      final a = SnapshotClient(), b = SnapshotClient();
      final ca = WorklistController(api: a, nomination: nomination),
          cb = WorklistController(api: b, nomination: nomination);
      addTearDown(ca.dispose);
      addTearDown(cb.dispose);
      await Future.wait([ca.refresh(), cb.refresh()]);
      cb.selectPiste(b.current.pistes.last.id);
      expect(
        ca.selected!.assignments.first.groupId,
        isNot(cb.selected!.assignments.first.groupId),
      );
      final sa = BoutSessionController(
            initialSession: ca.selected!.recommended!.bout.toSession(),
          ),
          sb = BoutSessionController(
            initialSession: cb.selected!.recommended!.bout.toSession(),
          );
      addTearDown(sa.dispose);
      addTearDown(sb.dispose);
      sa.setMutualHits(2);
      expect(sb.session.mutualHits, 0);
      final oldA = ca.selectedPisteId, oldB = cb.selectedPisteId;
      a.current = b.current = snapshot('reused');
      await Future.wait([ca.refresh(), cb.refresh()]);
      expect(ca.selectedPisteId, oldA);
      expect(cb.selectedPisteId, oldB);
      expect(
        ca.selected!.assignments.first.groupId,
        cb.selected!.assignments.first.groupId,
      );
      expect(
        ca.selected!.recommended!.bout.id,
        isNot(cb.selected!.recommended!.bout.id),
      );
      expect(ca.selected!.assignments.first.wave!.order, 2);
    },
  );
  test(
    'refresh during local bout preserves IDs, scores and assignment; remote change only flags review',
    () async {
      final api = SnapshotClient();
      final control = WorklistController(api: api, nomination: nomination);
      addTearDown(control.dispose);
      await control.refresh();
      final original = control.selected!.assignments.first.items.last.bout;
      final session = BoutSessionController(
        initialSession: original.toSession(),
      );
      addTearDown(session.dispose);
      session.setMutualHits(2);
      session.swapSides();
      expect(control.begin(original), isTrue);
      final frozen = session.session;
      api.current = snapshot('reused');
      await control.refresh();
      expect(identical(control.activeBout, original), isTrue);
      expect(identical(session.session, frozen), isTrue);
      expect(control.activeChanged, isTrue);
      expect(control.selectPiste(api.current.pistes.last.id), isFalse);
      expect(
        control.activeBout!.groupId,
        isNot(control.selected!.assignments.first.groupId),
      );
      control.end();
      expect(control.selectPiste(api.current.pistes.last.id), isTrue);
    },
  );
  test(
    'overlapping refresh is coalesced, failure preserves work, and stale revisions cannot replace it',
    () async {
      final api = SnapshotClient();
      final control = WorklistController(api: api, nomination: nomination);
      addTearDown(control.dispose);
      api.gate = Completer<TimerWorklist>();
      final first = control.refresh(), second = control.refresh();
      expect(identical(first, second), isTrue);
      expect(api.reads, 1);
      api.gate!.complete(snapshot('reused'));
      await first;
      api.gate = null;
      final old = control.work;
      api.current = snapshot('initial');
      await control.refresh();
      expect(control.error!.kind, ApiFailure.protocol);
      expect(identical(control.work, old), isTrue);
      api.unavailable = true;
      await control.refresh();
      expect(control.error!.kind, ApiFailure.unavailable);
      expect(identical(control.work, old), isTrue);
    },
  );
  test(
    'foreign tournament/nomination, wrong stage, duplicate bout and forged future READY fail closed',
    () {
      for (final mutate in <void Function(Json)>[
        (j) => object(array(j['piste_worklists']).first)['nomination_id'] =
            '00000000-0000-4000-8000-000000000999',
        (j) => object(array(j['piste_worklists']).first)['tournament_id'] =
            '00000000-0000-4000-8000-000000000999',
        (j) => object(
          object(
            array(object(array(j['piste_worklists']).first)['segments']).first,
          )['stage'],
        )['stage_id'] = '00000000-0000-4000-8000-000000000999',
        (j) {
          final segment = object(
            array(object(array(j['piste_worklists']).first)['segments']).first,
          );
          array(
            segment['items'],
          ).add(clone(object(array(segment['items']).first)));
        },
        (j) {
          final segment = object(
            array(object(array(j['piste_worklists']).first)['segments']).last,
          );
          final i = object(array(segment['items']).first);
          i['readiness'] = 'READY';
          object(object(i['bout'])['availability'])['available'] = true;
        },
      ]) {
        final j = clone(object(scenarios['initial']));
        mutate(j);
        expect(() => TimerWorklist.fromJson(j), throwsFormatException);
      }
    },
  );
  testWidgets(
    'polling uses 3 seconds idle, 15 during a bout and stops on dispose',
    (tester) async {
      final api = SnapshotClient();
      final c = WorklistController(api: api, nomination: nomination)
        ..startPolling();
      await tester.pump();
      expect(api.reads, 1);
      await tester.pump(const Duration(seconds: 3));
      await tester.pump();
      expect(api.reads, 2);
      expect(c.begin(c.selected!.recommended!.bout), isTrue);
      await tester.pump(const Duration(seconds: 3));
      expect(api.reads, 2);
      await tester.pump(const Duration(seconds: 12));
      await tester.pump();
      expect(api.reads, 3);
      c.dispose();
      await tester.pump(const Duration(seconds: 30));
      expect(api.reads, 3);
    },
  );
  setUp(
    () =>
        SharedPreferences.setMockInitialValues({'show_help_on_launch': false}),
  );
  testWidgets(
    'physical piste selection and future configuration display use server groups',
    (tester) async {
      tester.view.physicalSize = const Size(1000, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final api = SnapshotClient();
      await tester.pumpWidget(app(page(api)));
      await tester.pumpAndSettle();
      expect(find.text('Pools · Pool 1 · Piste 1'), findsOneWidget);
      expect(find.textContaining('Recommended next'), findsWidgets);
      await tester.tap(find.byKey(const Key('physical-piste')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Piste 2').last);
      await tester.pumpAndSettle();
      expect(find.text('Pools · Pool 2 · Piste 2'), findsOneWidget);
      expect(
        find.textContaining('Waiting for the organizer to start the group'),
        findsWidgets,
      );
      final future = api.current.pistes.last.assignments
          .where((a) => a.wave!.order == 2)
          .first
          .items
          .first;
      expect(
        tester
            .widget<ListTile>(find.byKey(ValueKey('bout-${future.bout.id}')))
            .enabled,
        isFalse,
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );
  testWidgets('non-recommended ready bout asks for confirmation, not denied', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final api = SnapshotClient();
    await tester.pumpWidget(app(page(api)));
    await tester.pumpAndSettle();
    final other = api.current.pistes.first.assignments.first.items[1];
    final row = find.byKey(ValueKey('bout-${other.bout.id}'));
    await tester.ensureVisible(row);
    await tester.pumpAndSettle();
    await tester.tap(row);
    await tester.pumpAndSettle();
    expect(find.text('Choose another ready bout?'), findsOneWidget);
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<ScorePage>(find.byType(ScorePage)).controller!.session.id,
      other.bout.id,
    );
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
  testWidgets(
    'refresh from score page preserves local session and warns of authoritative changes',
    (tester) async {
      tester.view.physicalSize = const Size(1000, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final api = SnapshotClient();
      await tester.pumpWidget(app(page(api)));
      await tester.pumpAndSettle();
      final item = api.current.pistes.first.recommended!;
      await tester.tap(find.byKey(ValueKey('bout-${item.bout.id}')));
      await tester.pumpAndSettle();
      final session = tester
          .widget<ScorePage>(find.byType(ScorePage))
          .controller!;
      session.setMutualHits(2);
      session.swapSides();
      await tester.pump();
      final draft = session.session;
      final rawPiste = object(
        array(object(scenarios['initial'])['piste_worklists']).first,
      );
      final rawSegment = object(array(rawPiste['segments']).first);
      final rawBout = object(object(array(rawSegment['items']).first)['bout']);
      api.overrideBout = TimerBout.fromJson({
        ...rawBout,
        'status': 'COMPLETED',
        'entity_version': item.bout.version + 1,
      });
      await tester.ensureVisible(find.text('Refresh').last);
      await tester.tap(find.text('Refresh').last);
      await tester.pumpAndSettle();
      expect(identical(session.session, draft), isTrue);
      expect(find.textContaining('Opossum changed this bout'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );
  testWidgets(
    'mobile Ukrainian configuration transition and running bout keep readable context',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final api = SnapshotClient()..current = snapshot('transitioned');
      await tester.pumpWidget(app(page(api), locale: 'uk'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Учасники змінюють ристалища'), findsWidgets);
      final item = api.current.pistes.first.recommended!;
      final row = find.byKey(ValueKey('bout-${item.bout.id}'));
      await tester.ensureVisible(row);
      await tester.pumpAndSettle();
      await tester.tap(row);
      await tester.pumpAndSettle();
      final start = find.text('СТАРТ');
      await tester.ensureVisible(start);
      await tester.pumpAndSettle();
      await tester.tap(start);
      await tester.pump();
      expect(
        tester.widget<ScorePage>(find.byType(ScorePage)).controller!.session.id,
        item.bout.id,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );
  testWidgets(
    'running 17-fighter worklist can expand all future configurations on mobile',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final source = object(array(scenarios['sizes']).last);
      final api = SnapshotClient()
        ..current = TimerWorklist.fromJson(object(source['before']));
      await tester.pumpWidget(app(page(api)));
      await tester.pumpAndSettle();
      final row = find.byKey(
        ValueKey('bout-${api.current.pistes.first.recommended!.bout.id}'),
      );
      await tester.ensureVisible(row);
      await tester.pumpAndSettle();
      await tester.tap(row);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('START'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('START'));
      await tester.pump();
      await tester.tap(find.text('Current and upcoming work'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );
}
