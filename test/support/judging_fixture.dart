import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:gdf_hema_timer/modules/opossum/models.dart';
import 'opossum_fixture.dart';

Json judgingFixture() => object(
  jsonDecode(File('test/fixtures/opossum_judging_v1.json').readAsStringSync()),
);

/// Replays authoritative TypeScript engine snapshots; no sporting calculations
/// are implemented by the fake client/server fixture.
class FakeJudgingServer extends FakeTimerServer {
  FakeJudgingServer([String scenario = 'rr'])
    : scenario = object(judgingFixture()[scenario]) {
    judging = clone(object(this.scenario['initial']));
    current = clone(object(judging['bout']));
  }
  final Json scenario;
  late Json judging;
  int judgeMutations = 0;
  int? denyJudge, denyJudgingRead;
  bool loseJudgeReceipt = false;
  final Map<String, ({String fingerprint, Json receipt})> judgeReceipts = {};
  @override
  Future<http.Response> handle(http.Request request) async {
    if (request.headers['authorization'] != 'Bearer $syntheticToken') {
      return refusal(401, 'UNAUTHENTICATED');
    }
    if (request.method == 'GET' && request.url.path.endsWith('/judging')) {
      if (failReads) return refusal(503, 'UNAVAILABLE');
      if (denyJudgingRead != null) {
        return refusal(denyJudgingRead!, 'UNAUTHENTICATED');
      }
      return response(judging);
    }
    if (request.method == 'POST' &&
        request.url.path.endsWith('/judge-events')) {
      writes.add(request);
      if (gate != null) await gate!.future;
      if (denyJudge != null) {
        return refusal(
          denyJudge!,
          denyJudge == 403
              ? 'INSUFFICIENT_SCOPE'
              : denyJudge == 401
              ? 'UNAUTHENTICATED'
              : 'ORGANIZER_REVIEW_REQUIRED',
        );
      }
      final body = object(jsonDecode(request.body));
      if (body.keys.any(
        (key) => ![
          'expected_pairing',
          'expected_judging_revision',
          'event',
          'client_event_id',
          'device_id',
          'submitted_at',
        ].contains(key),
      )) {
        return refusal(400, 'MALFORMED_REQUEST');
      }
      final key = request.headers['idempotency-key']!,
          eventId = text(body['client_event_id']);
      final fingerprint = '${request.headers['if-match']}:${request.body}';
      final old = judgeReceipts[key] ?? judgeReceipts[eventId];
      if (old != null) {
        if (old.fingerprint != fingerprint) {
          return refusal(409, 'IDEMPOTENCY_KEY_REUSED');
        }
        return response(old.receipt, headers: {'idempotency-replayed': 'true'});
      }
      if (request.headers['if-match'] != '"${current['entity_version']}"' ||
          body['expected_judging_revision'] != judging['judging_revision'] ||
          object(body['expected_pairing'])['fighter_a_id'] !=
              object(current['fighter_a'])['fighter_id'] ||
          object(body['expected_pairing'])['fighter_b_id'] !=
              object(current['fighter_b'])['fighter_id']) {
        return response({
          'error': 'STALE_ENTITY_VERSION',
          'message': 'Synthetic conflict',
          'current_judging': judging,
        }, status: 409);
      }
      final operations = array(scenario['operations']);
      if (judgeMutations >= operations.length) {
        return refusal(422, 'ORGANIZER_REVIEW_REQUIRED');
      }
      final operation = object(operations[judgeMutations]),
          expected = object(operation['event']),
          event = object(body['event']);
      if (event['type'] != expected['type'] ||
          event['participant_id'] != expected['participant_id']) {
        return refusal(422, 'INVALID_COMMAND');
      }
      judging = clone(object(operation['judging']));
      current = clone(object(judging['bout']));
      judgeMutations++;
      final record = object(array(judging['records']).last);
      final receipt = {
        'schema_version': 1,
        'source': 'timer',
        'record_id': record['record_id'],
        'client_event_id': eventId,
        'accepted_at': '2026-10-24T10:00:00.000Z',
        'judging': clone(judging),
      };
      judgeReceipts[key] = (fingerprint: fingerprint, receipt: receipt);
      judgeReceipts[eventId] = (fingerprint: fingerprint, receipt: receipt);
      if (loseJudgeReceipt && judgeMutations == 1) {
        return Completer<http.Response>().future;
      }
      return response(receipt, headers: {'idempotency-replayed': 'false'});
    }
    return super.handle(request);
  }
}
