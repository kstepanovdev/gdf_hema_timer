import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:gdf_hema_timer/modules/opossum/api_client.dart';
import 'package:gdf_hema_timer/modules/opossum/connection_storage.dart';
import 'package:gdf_hema_timer/modules/opossum/models.dart';

Json fixture() => object(
  jsonDecode(File('test/fixtures/opossum_v1.json').readAsStringSync()),
);
Json clone(Json value) => object(jsonDecode(jsonEncode(value)));
const syntheticToken = 'synthetic-device-token';
const deviceId = '00000000-0000-4000-8000-000000000fff';

class FakeTimerServer {
  FakeTimerServer() : data = fixture() {
    current = clone(object(data['bout']));
  }
  final Json data;
  late Json current;
  final List<http.Request> writes = [];
  final Map<String, ({String fingerprint, Json receipt})> accepted = {};
  int mutations = 0, reads = 0;
  int? denyWrites;
  bool loseFirstReceipt = false, failReads = false;
  Completer<void>? gate;
  http.Response response(
    Json value, {
    int status = 200,
    Map<String, String> headers = const {},
  }) => http.Response(
    jsonEncode(value),
    status,
    headers: {'content-type': 'application/json; charset=utf-8', ...headers},
  );
  http.Response refusal(int status, String code) => response({
    'error': code,
    'message': 'Synthetic rejection',
    'current_bout': current,
  }, status: status);
  http.Client client() => MockClient(handle);
  Future<http.Response> handle(http.Request request) async {
    if (request.headers['authorization'] != 'Bearer $syntheticToken') {
      return refusal(401, 'UNAUTHENTICATED');
    }
    if (request.method == 'GET') {
      reads++;
      if (failReads) return refusal(503, 'UNAVAILABLE');
      if (request.url.path == '/api/v1/timer/tournaments') {
        return response(object(data['discovery']));
      }
      if (request.url.path.endsWith('/worklist')) {
        final work = clone(object(data['worklist']));
        work['tournament_revision'] = current['tournament_revision'];
        for (final rawPiste in array(work['piste_worklists'])) {
          final piste = object(rawPiste);
          piste['tournament_revision'] = current['tournament_revision'];
          for (final rawSegment in array(piste['segments'])) {
            for (final rawItem in array(object(rawSegment)['items'])) {
              final item = object(rawItem);
              if (object(item['bout'])['bout_id'] == current['bout_id']) {
                item['bout'] = clone(current);
                item['readiness'] = current['status'] == 'COMPLETED'
                    ? 'COMPLETED'
                    : 'READY';
              }
            }
          }
        }
        return response(work);
      }
      if (request.url.path == '/api/v1/timer/bouts/${current['bout_id']}') {
        return response({'bout': current});
      }
      return refusal(404, 'NOT_FOUND');
    }
    writes.add(request);
    if (gate != null) await gate!.future;
    if (denyWrites != null) return refusal(denyWrites!, 'REFUSED');
    final body = object(jsonDecode(request.body));
    final key = request.headers['idempotency-key']!;
    final fingerprint = '${request.headers['if-match']}:${request.body}';
    if (accepted.containsKey(key)) {
      if (accepted[key]!.fingerprint != fingerprint) {
        return refusal(409, 'IDEMPOTENCY_KEY_REUSED');
      }
      return response(
        accepted[key]!.receipt,
        headers: {'idempotency-replayed': 'true'},
      );
    }
    if (request.headers['if-match'] != '"${current['entity_version']}"' ||
        object(body['expected_pairing'])['fighter_a_id'] !=
            object(current['fighter_a'])['fighter_id'] ||
        object(body['expected_pairing'])['fighter_b_id'] !=
            object(current['fighter_b'])['fighter_id']) {
      return refusal(409, 'ENTITY_VERSION_CONFLICT');
    }
    mutations++;
    current = {
      ...current,
      'status': 'COMPLETED',
      'result_type': body['result_type'],
      'score_a': body['score_a'],
      'score_b': body['score_b'],
      'entity_version': integer(current['entity_version']) + 1,
      'tournament_revision': '1',
      'availability': {'available': false, 'reason': 'BOUT_NOT_WRITABLE'},
    };
    final receipt = {
      for (final key in [
        'bout_id',
        'status',
        'result_type',
        'score_a',
        'score_b',
        'entity_version',
        'tournament_revision',
      ])
        key: current[key],
      'source': 'timer',
      'accepted_at': '2026-10-23T12:00:00Z',
    };
    accepted[key] = (fingerprint: fingerprint, receipt: receipt);
    if (loseFirstReceipt && mutations == 1) {
      return Completer<http.Response>().future;
    }
    return response(receipt, headers: {'idempotency-replayed': 'false'});
  }
}

class FakeConnectionStorage implements ConnectionStorage {
  ConnectionConfig? config;
  bool fail = false;
  @override
  bool get credentialsPersistent => true;
  @override
  Future<ConnectionConfig?> load() async => config;
  @override
  Future<String?> savedOrigin() async => config?.baseUrl.toString();
  @override
  Future<void> save(ConnectionConfig value) async {
    if (fail) throw StateError('keychain unavailable');
    config = value;
  }

  @override
  Future<void> forget() async {
    config = null;
  }

  @override
  Future<String> deviceId() async => '00000000-0000-4000-8000-000000000fff';
}

class AbortAwareTestClient extends http.BaseClient {
  bool closed = false;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    await (request as http.Abortable).abortTrigger;
    throw http.RequestAbortedException(request.url);
  }

  @override
  void close() {
    closed = true;
  }
}
