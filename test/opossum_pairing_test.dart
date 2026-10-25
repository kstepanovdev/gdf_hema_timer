import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:gdf_hema_timer/l10n/gen/app_localizations.dart';
import 'package:gdf_hema_timer/modules/opossum/api_client.dart';
import 'package:gdf_hema_timer/modules/opossum/models.dart';
import 'package:gdf_hema_timer/modules/opossum/pairing.dart';
import 'package:gdf_hema_timer/modules/opossum/outbox_sync.dart';
import 'package:gdf_hema_timer/modules/opossum/pending_submission.dart';
import 'package:gdf_hema_timer/modules/opossum/tournament_store.dart';
import 'package:gdf_hema_timer/pages/opossum_setup_page.dart';
import 'support/opossum_fixture.dart';
import 'opossum_persistence_test.dart' show makeSnapshot;

const code = 'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',
    token = 'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB';
String get link =>
    'opossum-timer:v1?${Uri(queryParameters: {'base': 'https://example.test', 'code': code}).query}';
Json issued() => {
  'token': token,
  'device': {
    'client_id': '00000000-0000-4000-8000-000000000028',
    'name': 'Paired tablet',
    'tournament_id': object(fixture()['bout'])['tournament_id'],
    'nomination_id': object(fixture()['bout'])['nomination_id'],
    'scopes': ['tournament:read', 'bout:read', 'bout:result:write'],
    'expires_at': '2030-01-01T00:00:00Z',
    'revoked_at': null,
  },
};
http.Response response(Json j, [int status = 200]) => http.Response(
  jsonEncode(j),
  status,
  headers: {'content-type': 'application/json'},
);
Widget app(Widget home) => MaterialApp(
  locale: const Locale('en'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: home,
);

class FakePairing implements PairingTransport {
  int calls = 0;
  bool closed = false;
  @override
  Future<PairedConnection> exchange(PairingLink value, String id) async {
    calls++;
    return PairedConnection.fromJson(issued(), value);
  }

  @override
  void close() => closed = true;
}

void main() {
  sqfliteFfiInit();
  setUp(
    () =>
        SharedPreferences.setMockInitialValues({'show_help_on_launch': false}),
  );
  test(
    'parses only one-time HTTPS pairing origins; rejects reusable tokens, duplicates and remote HTTP',
    () {
      final parsed = PairingLink.parse(link);
      expect(parsed.origin.toString(), 'https://example.test');
      expect(parsed.code, code);
      expect(parsed.toString(), isNot(contains(code)));
      for (final bad in [
        '$link&token=$token',
        '$link&base=https%3A%2F%2Fevil.test',
        '$link#fragment',
        link.replaceFirst('v1', 'v2'),
        link.replaceFirst(code, 'short'),
        link.replaceFirst('https%3A', 'http%3A'),
        'https://example.test?code=$code',
      ]) {
        expect(() => PairingLink.parse(bad), throwsFormatException);
      }
      final local =
          'opossum-timer:v1?${Uri(queryParameters: {'base': 'http://127.0.0.1:3000', 'code': code}).query}';
      expect(() => PairingLink.parse(local), throwsFormatException);
      expect(
        PairingLink.parse(local, allowLocalHttp: true).origin.scheme,
        'http',
      );
      expect(
        () => PairingLink.parse(
          link.replaceFirst('https%3A', 'http%3A'),
          allowLocalHttp: true,
        ),
        throwsFormatException,
      );
    },
  );
  test(
    'exchanges without bearer/redirects and coalesces double confirmation, retaining issued scope',
    () async {
      final gate = Completer<http.Response>();
      int requests = 0;
      final api = HttpPairingTransport(
        client: MockClient((request) async {
          requests++;
          expect(request.headers.containsKey('authorization'), isFalse);
          expect(request.followRedirects, isFalse);
          expect(request.url.path, '/api/v1/timer/pairings/exchange');
          expect(object(jsonDecode(request.body))['device_id'], deviceId);
          return gate.future;
        }),
      );
      addTearDown(api.close);
      final parsed = PairingLink.parse(link),
          a = api.exchange(parsed, deviceId),
          b = api.exchange(parsed, deviceId);
      expect(identical(a, b), isTrue);
      await expectLater(
        api.exchange(
          PairingLink.parse(link.replaceFirst(code, 'C' * 43)),
          deviceId,
        ),
        throwsA(
          isA<OpossumException>().having(
            (e) => e.kind,
            'kind',
            ApiFailure.conflict,
          ),
        ),
      );
      gate.complete(response(issued()));
      final value = await a;
      expect(requests, 1);
      expect(value.config.token, token);
      expect(
        value.identity.tournamentId,
        object(fixture()['bout'])['tournament_id'],
      );
      expect(value.toString(), isNot(contains(token)));
    },
  );
  for (final status in [404, 429, 503, 302]) {
    test(
      'typed pairing failure $status does not expose response secrets or retry a one-time exchange',
      () async {
        int requests = 0;
        final api = HttpPairingTransport(
          client: MockClient((_) async {
            requests++;
            return response({'error': code, 'token': token}, status);
          }),
        );
        addTearDown(api.close);
        try {
          await api.exchange(PairingLink.parse(link), deviceId);
          fail('Expected rejection');
        } on OpossumException catch (e) {
          expect(e.toString(), isNot(contains(code)));
          expect(e.toString(), isNot(contains(token)));
          expect(e.kind, switch (status) {
            404 => ApiFailure.rejected,
            429 => ApiFailure.rateLimited,
            503 => ApiFailure.unavailable,
            _ => ApiFailure.protocol,
          });
        }
        expect(requests, 1);
      },
    );
  }
  test(
    'timeout after accepted exchange is uncertain and never performs blind retry',
    () async {
      var calls = 0;
      final api = HttpPairingTransport(
        timeout: const Duration(milliseconds: 15),
        client: MockClient((_) {
          calls++;
          return Completer<http.Response>().future;
        }),
      );
      addTearDown(api.close);
      await expectLater(
        api.exchange(PairingLink.parse(link), deviceId),
        throwsA(
          isA<OpossumException>().having(
            (e) => e.kind,
            'kind',
            ApiFailure.timeout,
          ),
        ),
      );
      expect(calls, 1);
    },
  );
  test(
    'identity lookup accepts the actual v1 contract; revoked credentials never fall back to legacy discovery',
    () async {
      final config = ConnectionConfig('https://example.test', token);
      final me = {
        ...object(issued()['device']),
        'schema_version': 1,
        'api_features': ['pairing', 'worklist'],
      };
      final api = HttpOpossumClient(
        config,
        client: MockClient((_) async => response(me)),
        readRetries: 0,
      );
      addTearDown(api.close);
      expect((await api.identity())!.features, contains('pairing'));
      final revoked = HttpOpossumClient(
        config,
        client: MockClient(
          (_) async => response({'error': 'UNAUTHENTICATED'}, 401),
        ),
        readRetries: 0,
      );
      addTearDown(revoked.close);
      await expectLater(
        revoked.identity(),
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
  test(
    're-pairing and an invalid credential cannot rebind or delete old confirmed sporting evidence',
    () async {
      final dir = await Directory.systemTemp.createTemp('pair-recovery-'),
          path = '${dir.path}/test.sqlite';
      var store = await TournamentStore.open(databaseFactoryFfi, path);
      final old = makeSnapshot(TimerBout.fromJson(object(fixture()['bout']))),
          request = PendingSubmission.confirm(
            origin: old.origin,
            bout: old.bout,
            session: old.session,
            deviceId: deviceId,
          );
      await store.confirm(request, old, credentialFingerprint(syntheticToken));
      await store.close();
      store = await TournamentStore.open(databaseFactoryFfi, path);
      final server = FakeTimerServer(),
          api = HttpOpossumClient(
            ConnectionConfig('https://example.test', token),
            client: server.client(),
            readRetries: 0,
          ),
          sync = OutboxSync(
            store: store,
            api: api,
            origin: old.origin,
            credentialRef: credentialFingerprint(token),
          );
      await sync.flush();
      final entry = (await store.entries()).single;
      expect(entry.request.toJson(), request.toJson());
      expect(entry.state, OutboxState.authentication);
      expect(entry.errorCode, 'CREDENTIAL_CHANGED');
      expect(server.writes, isEmpty);
      expect(entry.snapshot.session.a.score, 5);
      sync.dispose();
      api.close();
      await store.close();
      await dir.delete(recursive: true);
    },
  );
  Future<void> showSetup(
    WidgetTester tester,
    FakeConnectionStorage storage,
    FakePairing pairing, {
    bool scan = true,
  }) async {
    tester.view.physicalSize = const Size(1000, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final server = FakeTimerServer();
    await tester.pumpWidget(
      app(
        OpossumSetupPage(
          storage: storage,
          repository: MemoryPendingSubmissionRepository(),
          pairingTransport: pairing,
          scanQr: scan ? (_) => Future.value(link) : null,
          createClient: (config) => HttpOpossumClient(
            config,
            readRetries: 0,
            client: MockClient((request) {
              request.headers['authorization'] = 'Bearer $syntheticToken';
              return server.handle(request);
            }),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'scan, confirm server origin, store credential securely, load permitted nomination and reuse after restart',
    (tester) async {
      final storage = FakeConnectionStorage(), pair = FakePairing();
      await showSetup(tester, storage, pair);
      await tester.tap(find.text('Scan pairing QR'));
      await tester.pumpAndSettle();
      expect(find.text('Connect to this Opossum server?'), findsOneWidget);
      expect(pair.calls, 0);
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(pair.calls, 1);
      expect(storage.config!.token, token);
      expect(find.text('Connection verified'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      await showSetup(tester, storage, FakePairing());
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('opossum-token')))
            .controller!
            .text,
        token,
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );
  testWidgets(
    'camera/manual fallback and secure-storage failure keep credentials available for deliberate retry without a second exchange',
    (tester) async {
      final storage = FakeConnectionStorage()..fail = true,
          pair = FakePairing();
      await showSetup(tester, storage, pair, scan: false);
      expect(find.text('Manual URL + device token'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('pairing-link')), link);
      await tester.tap(find.text('Use pairing link'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(pair.calls, 1);
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('opossum-token')))
            .controller!
            .text,
        token,
      );
      expect(find.byKey(const Key('connection-error')), findsOneWidget);
      storage.fail = false;
      await tester.tap(find.text('Test and save connection'));
      await tester.pumpAndSettle();
      expect(storage.config!.token, token);
      expect(pair.calls, 1);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );
}
