import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gdf_hema_timer/modules/bout_session/bout_session.dart';
import 'package:gdf_hema_timer/modules/bout_session/bout_session_controller.dart';
import 'package:gdf_hema_timer/modules/opossum/api_client.dart';
import 'package:gdf_hema_timer/modules/opossum/connection_storage.dart';
import 'package:gdf_hema_timer/modules/opossum/models.dart';
import 'package:gdf_hema_timer/modules/opossum/pending_submission.dart';
import 'package:gdf_hema_timer/modules/opossum/submission_controller.dart';
import 'support/opossum_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeTimerServer server;
  late HttpOpossumClient api;
  late TimerBout bout;
  late NominationRef nomination;
  late BoutSessionController session;
  late MemoryPendingSubmissionRepository repository;
  late SubmissionController submission;
  setUp(() {
    server = FakeTimerServer();
    api = HttpOpossumClient(
      ConnectionConfig('https://example.test', syntheticToken),
      client: server.client(),
      readRetries: 0,
      timeout: const Duration(milliseconds: 30),
    );
    bout = TimerBout.fromJson(server.current);
    nomination = NominationRef.fromJson(
      object(array(object(server.data['discovery'])['nominations']).first),
    );
    session = BoutSessionController(initialSession: bout.toSession());
    session.setScore(DisplaySide.left, 5);
    session.setScore(DisplaySide.right, 1);
    repository = MemoryPendingSubmissionRepository();
    submission = SubmissionController(
      api: api,
      repository: repository,
      origin: 'https://example.test',
      nomination: nomination,
      bout: bout,
      session: session.session,
      deviceId: deviceId,
    );
  });
  tearDown(() {
    submission.dispose();
    session.dispose();
    api.close();
  });

  test(
    'connection discovery, nomination scope and real versioned worklist schema',
    () async {
      final nominations = await api.discover();
      expect(nominations.single.tournamentId, nomination.tournamentId);
      final work = await api.worklist(nominations.single);
      expect(work.assignments, hasLength(1));
      expect(work.assignments.single.items, hasLength(6));
      expect(work.assignments.single.items.first.selectable, isTrue);
      expect((await api.bout(bout.id)).a!.id, bout.a!.id);
    },
  );
  test(
    'worklist polling sends scoped revision validators and handles 304 without losing assignments',
    () async {
      var requests = 0;
      final cachedClient = HttpOpossumClient(
        ConnectionConfig('https://example.test', syntheticToken),
        client: MockClient((request) async {
          requests++;
          if (requests == 1) {
            expect(request.headers['if-none-match'], isNull);
            return server.response(object(server.data['worklist']));
          }
          expect(request.headers['if-none-match'], '"0"');
          if (requests == 2) return http.Response('', 304);
          return server.refusal(401, 'UNAUTHENTICATED');
        }),
      );
      addTearDown(cachedClient.close);
      final first = await cachedClient.worklist(nomination),
          second = await cachedClient.worklist(nomination);
      expect(identical(first, second), isTrue);
      await expectLater(
        cachedClient.worklist(nomination),
        throwsA(
          isA<OpossumException>().having(
            (e) => e.kind,
            'kind',
            ApiFailure.authentication,
          ),
        ),
      );
    },
  );
  test('invalid credential is typed and never printed', () async {
    final invalid = HttpOpossumClient(
      ConnectionConfig('https://example.test', 'private-unknown-token'),
      client: server.client(),
    );
    addTearDown(invalid.close);
    await expectLater(
      invalid.discover(),
      throwsA(
        isA<OpossumException>().having(
          (e) => e.kind,
          'kind',
          ApiFailure.authentication,
        ),
      ),
    );
    expect(
      ConnectionConfig(
        'https://example.test',
        'private-unknown-token',
      ).toString(),
      isNot(contains('private-unknown-token')),
    );
  });
  test(
    'server outage retries safe reads only a bounded number of times',
    () async {
      server.failReads = true;
      final retrying = HttpOpossumClient(
        ConnectionConfig('https://example.test', syntheticToken),
        client: server.client(),
        readRetries: 1,
      );
      addTearDown(retrying.close);
      await expectLater(
        retrying.discover(),
        throwsA(
          isA<OpossumException>().having(
            (e) => e.kind,
            'kind',
            ApiFailure.unavailable,
          ),
        ),
      );
      expect(server.reads, 2);
    },
  );
  test(
    'HTTPS default, explicit loopback exception, no URL credentials/query or LAN HTTP',
    () {
      for (final address in [
        'http://example.test',
        'http://192.168.1.10',
        'https://token@example.test',
        'https://example.test/?token=secret',
        'https://example.test/api',
      ]) {
        expect(
          () => ConnectionConfig(address, syntheticToken, allowLocalHttp: true),
          throwsFormatException,
        );
      }
      expect(
        () => ConnectionConfig('http://localhost:3000', syntheticToken),
        throwsFormatException,
      );
      expect(
        ConnectionConfig(
          'http://127.0.0.1:3000',
          syntheticToken,
          allowLocalHttp: true,
        ).baseUrl.host,
        '127.0.0.1',
      );
    },
  );
  test(
    'redirect responses are refused and requests forbid following redirects',
    () async {
      final redirected = HttpOpossumClient(
        ConnectionConfig('https://example.test', syntheticToken),
        client: MockClient((req) async {
          expect(req.followRedirects, isFalse);
          return http.Response(
            '',
            302,
            headers: {'location': 'https://untrusted.test'},
          );
        }),
      );
      addTearDown(redirected.close);
      await expectLater(
        redirected.discover(),
        throwsA(
          isA<OpossumException>().having(
            (e) => e.kind,
            'kind',
            ApiFailure.protocol,
          ),
        ),
      );
    },
  );
  test(
    'side swap preserves expected pairing and logical score orientation',
    () async {
      session.swapSides();
      session.setScore(DisplaySide.left, 3);
      final request = PendingSubmission.confirm(
        origin: 'https://example.test',
        bout: bout,
        session: session.session,
        deviceId: deviceId,
      );
      expect(request.scoreA, 5);
      expect(request.scoreB, 3);
      expect(request.body['expected_pairing'], {
        'fighter_a_id': bout.a!.id,
        'fighter_b_id': bout.b!.id,
      });
      expect(
        PendingSubmission.fromJson(
          jsonDecode(jsonEncode(request.toJson())),
        ).toJson(),
        request.toJson(),
      );
      session.reset(duration: const Duration(seconds: 90));
      expect(session.session.a.id, bout.a!.id);
      expect(session.session.id, bout.id);
    },
  );
  test(
    'confirm submits once, stores envelope and refreshes authoritative bout/worklist',
    () async {
      await submission.confirm();
      expect(submission.state, SubmissionState.accepted);
      expect(submission.receipt!.replayed, isFalse);
      expect(submission.authoritativeBout!.status, 'COMPLETED');
      expect(submission.authoritativeWorklist!.serverRevision, '1');
      expect(repository.durable, isFalse);
      expect(
        (await repository.find(submission.request!.clientEventId))!.toJson(),
        submission.request!.toJson(),
      );
      await submission.confirm();
      expect(server.mutations, 1);
      expect(server.writes, hasLength(1));
    },
  );
  test('double confirmation joins the same in-flight mutation', () async {
    server.gate = Completer<void>();
    final first = submission.confirm();
    final second = submission.confirm();
    await Future<void>.delayed(Duration.zero);
    expect(server.writes, hasLength(1));
    server.gate!.complete();
    await Future.wait([first, second]);
    expect(server.mutations, 1);
    expect(submission.state, SubmissionState.accepted);
  });
  test(
    'timeout after server acceptance preserves exact identities/body for replay',
    () async {
      server.loseFirstReceipt = true;
      await submission.confirm();
      expect(submission.state, SubmissionState.uncertain);
      expect(server.mutations, 1);
      final envelope = submission.request!.toJson();
      await submission.confirm();
      expect(submission.state, SubmissionState.accepted);
      expect(submission.receipt!.replayed, isTrue);
      expect(submission.request!.toJson(), envelope);
      expect(server.writes[0].body, server.writes[1].body);
      expect(
        server.writes[0].headers['idempotency-key'],
        server.writes[1].headers['idempotency-key'],
      );
      expect(
        server.writes[0].headers['if-match'],
        server.writes[1].headers['if-match'],
      );
      expect(server.mutations, 1);
    },
  );
  for (final pairing in [false, true]) {
    test(
      pairing
          ? 'changed pairing is never overwritten'
          : 'stale entity version is never overwritten',
      () async {
        if (pairing) {
          server.current['fighter_a'] = server.current['fighter_b'];
        } else {
          server.current['entity_version'] = bout.version + 1;
        }
        await submission.confirm();
        expect(submission.state, SubmissionState.conflict);
        expect(submission.error!.currentBout, isNotNull);
        await submission.confirm();
        expect(server.writes, hasLength(1));
        expect(server.mutations, 0);
      },
    );
  }
  for (final (status, state) in [
    (401, SubmissionState.authentication),
    (403, SubmissionState.forbidden),
    (422, SubmissionState.rejected),
  ]) {
    test('result refusal $status remains distinct', () async {
      server.denyWrites = status;
      await submission.confirm();
      expect(submission.state, state);
      expect(server.mutations, 0);
    });
  }
  test('invalid JSON and cross-nomination worklists fail closed', () async {
    final invalid = HttpOpossumClient(
      ConnectionConfig('https://example.test', syntheticToken),
      client: MockClient((_) async => http.Response('{', 200)),
    );
    addTearDown(invalid.close);
    await expectLater(
      invalid.discover(),
      throwsA(
        isA<OpossumException>().having(
          (e) => e.kind,
          'kind',
          ApiFailure.protocol,
        ),
      ),
    );
    final wrong = clone(object(server.data['worklist']));
    wrong['nomination_id'] = deviceId;
    final other = HttpOpossumClient(
      ConnectionConfig('https://example.test', syntheticToken),
      client: MockClient((_) async => http.Response(jsonEncode(wrong), 200)),
    );
    addTearDown(other.close);
    await expectLater(
      other.worklist(nomination),
      throwsA(isA<OpossumException>()),
    );
  });
  test(
    'local mutual-hit changes cannot be silently omitted from NORMAL result',
    () {
      session.setMutualHits(3);
      expect(
        () => PendingSubmission.confirm(
          origin: 'https://example.test',
          bout: bout,
          session: session.session,
          deviceId: deviceId,
        ),
        throwsFormatException,
      );
      expect(server.writes, isEmpty);
    },
  );
  test(
    'equal scores remain NORMAL draw, not manufactured Double Loss',
    () async {
      session.setScore(DisplaySide.right, 5);
      final request = PendingSubmission.confirm(
        origin: 'https://example.test',
        bout: bout,
        session: session.session,
        deviceId: deviceId,
      );
      expect(request.body['result_type'], 'NORMAL');
      final accepted = await api.submit(request);
      expect(accepted.scoreA, accepted.scoreB);
    },
  );
  test('missing readiness/non-writable result cannot be confirmed', () {
    final locked = clone(server.current)..remove('availability');
    final value = TimerBout.fromJson(locked);
    expect(value.writable, isFalse);
    expect(
      () => PendingSubmission.confirm(
        origin: 'https://example.test',
        bout: value,
        session: session.session,
        deviceId: deviceId,
      ),
      throwsFormatException,
    );
  });
  test(
    'accepted result stays accepted when refresh fails; never resend',
    () async {
      final request = submission.confirm();
      await request;
      server.failReads = true;
      await submission.refresh();
      expect(submission.state, SubmissionState.accepted);
      expect(submission.refreshFailed, isTrue);
      await submission.confirm();
      expect(server.writes, hasLength(1));
    },
  );
  test(
    'credential storage roundtrip uses secure adapter, not shared preferences',
    () async {
      SharedPreferences.setMockInitialValues({});
      FlutterSecureStorage.setMockInitialValues({});
      final storage = PlatformConnectionStorage();
      await storage.save(
        ConnectionConfig('https://example.test', syntheticToken),
      );
      expect((await storage.load())!.token, syntheticToken);
      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getKeys().any(
          (key) => '${prefs.get(key)}'.contains(syntheticToken),
        ),
        isFalse,
      );
      expect(await storage.deviceId(), await storage.deviceId());
      await storage.forget();
      expect(await storage.load(), isNull);
    },
  );
  test(
    'disposing the client aborts in-flight reads without retrying',
    () async {
      final transport = AbortAwareTestClient();
      final cancellable = HttpOpossumClient(
        ConnectionConfig('https://example.test', syntheticToken),
        client: transport,
      );
      final pending = cancellable.discover();
      cancellable.close();
      await expectLater(
        pending,
        throwsA(
          isA<OpossumException>().having(
            (e) => e.kind,
            'kind',
            ApiFailure.cancelled,
          ),
        ),
      );
      expect(transport.closed, isTrue);
    },
  );
  test(
    'corrupt non-secret device metadata is replaced with a valid stable ID',
    () async {
      SharedPreferences.setMockInitialValues({'opossum_device_id': 'invalid'});
      final storage = PlatformConnectionStorage();
      final first = await storage.deviceId();
      expect(uuid(first), first);
      expect(await storage.deviceId(), first);
    },
  );
  test(
    'unchanged authoritative mutual hits remain unchanged, never submitted as new events',
    () {
      final data = clone(server.current);
      object(data['mutual_hits'])['effective_count'] = 2;
      final loaded = TimerBout.fromJson(data);
      final request = PendingSubmission.confirm(
        origin: 'https://example.test',
        bout: loaded,
        session: loaded.toSession(),
        deviceId: deviceId,
      );
      expect(request.body.containsKey('mutual_hits'), isFalse);
      expect(request.body['result_type'], 'NORMAL');
    },
  );
}
