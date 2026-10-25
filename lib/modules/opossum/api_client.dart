import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'models.dart';
import 'pending_submission.dart';
import 'judging.dart';
import 'pairing.dart';

enum ApiFailure {
  storage,
  localPersistence,
  authentication,
  forbidden,
  conflict,
  rejected,
  unavailable,
  timeout,
  protocol,
  cancelled,
  rateLimited,
}

class OpossumException implements Exception {
  const OpossumException(
    this.kind, {
    this.code,
    this.currentBout,
    this.retryAfter,
  });
  final ApiFailure kind;
  final String? code;
  final TimerBout? currentBout;
  final Duration? retryAfter;
  @override
  String toString() => 'OpossumException(${kind.name})'; // Never include URLs, bodies or tokens.
}

class ConnectionConfig {
  ConnectionConfig(String url, String token, {this.allowLocalHttp = false})
    : baseUrl = validateBaseUrl(url, allowLocalHttp: allowLocalHttp),
      token = token.trim() {
    if (this.token.isEmpty || this.token.contains(RegExp(r'\s'))) {
      throw const FormatException('token');
    }
  }
  final Uri baseUrl;
  final String token;
  final bool allowLocalHttp;
  static Uri validateBaseUrl(String value, {bool allowLocalHttp = false}) {
    final uri = Uri.tryParse(value.trim());
    if (uri == null ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        (uri.path.isNotEmpty && uri.path != '/') ||
        !(uri.scheme == 'https' ||
            (allowLocalHttp &&
                uri.scheme == 'http' &&
                [
                  'localhost',
                  '127.0.0.1',
                  '[::1]',
                  '::1',
                ].contains(uri.host)))) {
      throw const FormatException(
        'HTTPS origin required (explicit loopback development exception only)',
      );
    }
    return uri.replace(path: '');
  }
}

abstract class OpossumClient {
  Future<List<NominationRef>> discover();
  Future<TimerWorklist> worklist(NominationRef nomination);
  Future<TimerBout> bout(String id);
  Future<AcceptedResult> submit(PendingSubmission request);
  void close();
}

abstract interface class OpossumJudgingClient {
  Future<JudgingState> judging(String boutId);
  Future<JudgingReceipt> submitJudge(PendingSubmission request);
}

class HttpOpossumClient implements OpossumClient, OpossumJudgingClient {
  HttpOpossumClient(
    this.config, {
    http.Client? client,
    this.timeout = const Duration(seconds: 12),
    this.readRetries = 1,
  }) : _client = client ?? http.Client();
  final ConnectionConfig config;
  final http.Client _client;
  final Duration timeout;
  final int readRetries;
  bool _closed = false;
  final Map<String, TimerWorklist> _worklists = {};
  final Set<Completer<void>> _requests = {};

  Future<TimerDeviceIdentity?> identity() async {
    final response = await _request(
      'GET',
      '/api/v1/timer/me',
      allowNotFound: true,
    );
    if (response.statusCode == 404) {
      return null; // Legacy server; discovery still authenticates.
    }
    try {
      return TimerDeviceIdentity.fromJson(
        object(jsonDecode(utf8.decode(response.bodyBytes))),
      );
    } catch (_) {
      throw const OpossumException(ApiFailure.protocol);
    }
  }

  Future<http.Response> _request(
    String method,
    String path, {
    Map<String, String> headers = const {},
    Json? body,
    bool allowNotModified = false,
    bool allowNotFound = false,
  }) async {
    for (var attempt = 0; ; attempt++) {
      if (_closed) throw const OpossumException(ApiFailure.cancelled);
      final abort = Completer<void>();
      _requests.add(abort);
      try {
        final request =
            http.AbortableRequest(
                method,
                config.baseUrl.resolve(path),
                abortTrigger: abort.future,
              )
              ..followRedirects =
                  false // Never forward credentials to a redirected origin.
              ..headers.addAll({
                'authorization': 'Bearer ${config.token}',
                'accept': 'application/json',
                ...headers,
              });
        if (body != null) {
          request.headers['content-type'] = 'application/json';
          request.body = jsonEncode(body);
        }
        final response =
            await (() async {
              final streamed = await _client.send(request);
              final bytes = <int>[];
              await for (final chunk in streamed.stream) {
                if (bytes.length + chunk.length > 2 * 1024 * 1024) {
                  throw const OpossumException(ApiFailure.protocol);
                }
                bytes.addAll(chunk);
              }
              return http.Response.bytes(
                bytes,
                streamed.statusCode,
                headers: streamed.headers,
              );
            })().timeout(
              timeout,
              onTimeout: () {
                if (!abort.isCompleted) abort.complete();
                throw const OpossumException(ApiFailure.timeout);
              },
            );
        if (_closed) throw const OpossumException(ApiFailure.cancelled);
        if ((allowNotFound && response.statusCode == 404) ||
            (allowNotModified && response.statusCode == 304) ||
            (response.statusCode >= 200 && response.statusCode < 300)) {
          return response;
        }
        Json? error;
        try {
          error = object(jsonDecode(utf8.decode(response.bodyBytes)));
        } catch (_) {
          /* proxy errors can be HTML */
        }
        final rawCode = error?['error'];
        final code =
            rawCode is String && RegExp(r'^[A-Z_0-9]{1,100}$').hasMatch(rawCode)
            ? rawCode
            : null;
        TimerBout? current;
        try {
          if (error?['current_bout'] != null) {
            current = TimerBout.fromJson(object(error!['current_bout']));
          } else if (error?['current_judging'] != null) {
            current = JudgingState.fromJson(
              object(error!['current_judging']),
            ).bout;
          }
        } catch (_) {
          /* no trusted current snapshot */
        }
        final seconds = int.tryParse(response.headers['retry-after'] ?? '');
        throw OpossumException(
          switch (response.statusCode) {
            401 => ApiFailure.authentication,
            403 => ApiFailure.forbidden,
            409 => ApiFailure.conflict,
            429 => ApiFailure.rateLimited,
            >= 500 => ApiFailure.unavailable,
            400 || 404 || 422 => ApiFailure.rejected,
            _ => ApiFailure.protocol,
          },
          code: code,
          currentBout: current,
          retryAfter: seconds != null && seconds > 0
              ? Duration(seconds: seconds)
              : null,
        );
      } catch (error) {
        final failure = error is OpossumException
            ? error
            : OpossumException(
                _closed ? ApiFailure.cancelled : ApiFailure.unavailable,
              );
        if (method != 'GET' ||
            attempt >= readRetries.clamp(0, 2) ||
            ![
              ApiFailure.timeout,
              ApiFailure.unavailable,
            ].contains(failure.kind) ||
            _closed) {
          rethrowFailure(failure);
        }
        await Future<void>.delayed(const Duration(milliseconds: 200));
      } finally {
        _requests.remove(abort);
        if (!abort.isCompleted) abort.complete();
      }
    }
  }

  Never rethrowFailure(OpossumException error) => throw error;
  T _decode<T>(http.Response response, T Function(Json) parse) {
    try {
      return parse(object(jsonDecode(utf8.decode(response.bodyBytes))));
    } catch (_) {
      throw const OpossumException(ApiFailure.protocol);
    }
  }

  @override
  Future<List<NominationRef>> discover() async => _decode(
    await _request('GET', '/api/v1/timer/tournaments?status=active'),
    (json) => List.unmodifiable(
      array(json['nominations']).map((e) => NominationRef.fromJson(object(e))),
    ),
  );
  @override
  Future<TimerWorklist> worklist(NominationRef nomination) async {
    final key = '${nomination.tournamentId}/${nomination.id}';
    final cached = _worklists[key];
    final response = await _request(
      'GET',
      '/api/v1/timer/tournaments/${nomination.tournamentId}/nominations/${nomination.id}/worklist',
      headers: {
        if (cached != null) 'if-none-match': '"${cached.serverRevision}"',
      },
      allowNotModified: cached != null,
    );
    final result = response.statusCode == 304
        ? cached!
        : _decode(response, TimerWorklist.fromJson);
    if (result.tournamentId != nomination.tournamentId ||
        result.nominationId != nomination.id) {
      throw const OpossumException(ApiFailure.protocol);
    }
    _worklists[key] = result;
    return result;
  }

  @override
  Future<TimerBout> bout(String id) async {
    uuid(id);
    final result = _decode(
      await _request('GET', '/api/v1/timer/bouts/$id'),
      (j) => TimerBout.fromJson(object(j['bout'])),
    );
    if (result.id != id) throw const OpossumException(ApiFailure.protocol);
    return result;
  }

  @override
  Future<AcceptedResult> submit(PendingSubmission request) async {
    if (request.isJudge) throw const OpossumException(ApiFailure.protocol);
    if (request.origin != config.baseUrl.toString()) {
      throw const OpossumException(
        ApiFailure.rejected,
        code: 'CONNECTION_CHANGED',
      );
    }
    final response = await _request(
      'PUT',
      '/api/v1/timer/bouts/${request.boutId}/result',
      headers: {
        'if-match': '"${request.version}"',
        'idempotency-key': request.idempotencyKey,
      },
      body: request.body,
    );
    return _decode(response, (json) {
      final replay = response.headers['idempotency-replayed'];
      final result = AcceptedResult.fromJson(
        json,
        replayed: replay == null ? null : replay == 'true',
      );
      if (result.boutId != request.boutId ||
          result.scoreA != request.scoreA ||
          result.scoreB != request.scoreB ||
          result.resultType != 'NORMAL' ||
          result.version <= request.version) {
        throw const FormatException('receipt mismatch');
      }
      return result;
    });
  }

  @override
  Future<JudgingState> judging(String boutId) async {
    uuid(boutId);
    final state = _decode(
      await _request('GET', '/api/v1/timer/bouts/$boutId/judging'),
      JudgingState.fromJson,
    );
    if (state.bout.id != boutId) {
      throw const OpossumException(ApiFailure.protocol);
    }
    return state;
  }

  @override
  Future<JudgingReceipt> submitJudge(PendingSubmission request) async {
    if (!request.isJudge || request.origin != config.baseUrl.toString()) {
      throw const OpossumException(
        ApiFailure.rejected,
        code: 'CONNECTION_CHANGED',
      );
    }
    final response = await _request(
      'POST',
      '/api/v1/timer/bouts/${request.boutId}/judge-events',
      headers: {
        'if-match': '"${request.version}"',
        'idempotency-key': request.idempotencyKey,
      },
      body: request.body,
    );
    return _decode(response, (json) {
      final receipt = JudgingReceipt.fromJson(json);
      final b = receipt.state.bout;
      final record = receipt.state.records.singleWhere(
        (r) => r['record_id'] == receipt.recordId,
      );
      if (receipt.eventId != request.clientEventId ||
          b.id != request.boutId ||
          b.nominationId != request.nominationId ||
          b.tournamentId != request.tournamentId ||
          b.a?.id != request.fighterAId ||
          b.b?.id != request.fighterBId ||
          b.version <= request.version ||
          record['type'] != request.judgeEvent!['type'] ||
          record['participant_id'] != request.judgeEvent!['participant_id'] ||
          record['issued_by_this_device'] != true ||
          record['voided_at'] != null) {
        throw const FormatException('judge receipt mismatch');
      }
      return receipt;
    });
  }

  @override
  void close() {
    _closed = true;
    for (final request in _requests) {
      if (!request.isCompleted) request.complete();
    }
    _client.close();
  }
}
