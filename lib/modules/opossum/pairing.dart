import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_client.dart';
import 'models.dart';

/// The payload is never a URL to launch or log. Secrets stay out of navigation.
class PairingLink {
  PairingLink._(this.origin, this.code, this.allowLocalHttp);
  final Uri origin;
  final String code;
  final bool allowLocalHttp;
  factory PairingLink.parse(String value, {bool allowLocalHttp = false}) {
    final uri = Uri.tryParse(value.trim());
    if (uri == null ||
        uri.scheme != 'opossum-timer' ||
        uri.path != 'v1' ||
        uri.hasAuthority ||
        uri.hasFragment ||
        uri.queryParametersAll.length != 2 ||
        uri.queryParametersAll.keys.any((k) => !['base', 'code'].contains(k)) ||
        uri.queryParametersAll.values.any((v) => v.length != 1)) {
      throw const FormatException('Invalid pairing payload');
    }
    final code = uri.queryParameters['code']!;
    if (!RegExp(r'^[A-Za-z0-9_-]{43}$').hasMatch(code)) {
      throw const FormatException('Invalid pairing payload');
    }
    return PairingLink._(
      ConnectionConfig.validateBaseUrl(
        uri.queryParameters['base']!,
        allowLocalHttp: allowLocalHttp,
      ),
      code,
      allowLocalHttp,
    );
  }
  @override
  String toString() => 'PairingLink([redacted])';
}

class TimerDeviceIdentity {
  TimerDeviceIdentity.fromJson(Json j)
    : id = uuid(j['client_id']),
      name = text(j['name']),
      tournamentId = j['tournament_id'] == null
          ? null
          : uuid(j['tournament_id']),
      nominationId = j['nomination_id'] == null
          ? null
          : uuid(j['nomination_id']),
      scopes = List.unmodifiable(array(j['scopes']).map(text)),
      expiresAt = j['expires_at'] == null
          ? null
          : DateTime.parse(text(j['expires_at'])),
      features = List.unmodifiable(array(j['api_features']).map(text)) {
    if (j['schema_version'] != 1 ||
        (nominationId != null && tournamentId == null)) {
      throw const FormatException('Device contract');
    }
  }
  final String id, name;
  final String? tournamentId, nominationId;
  final List<String> scopes, features;
  final DateTime? expiresAt;
}

class PairedConnection {
  PairedConnection.fromJson(Json j, PairingLink link)
    : config = ConnectionConfig(
        link.origin.toString(),
        text(j['token']),
        allowLocalHttp: link.allowLocalHttp,
      ),
      identity = TimerDeviceIdentity.fromJson({
        ...object(j['device']),
        'schema_version': 1,
        'api_features': <String>[],
      }) {
    if (identity.tournamentId == null ||
        identity.expiresAt == null ||
        object(j['device'])['revoked_at'] != null ||
        config.token.length < 32) {
      throw const FormatException('Issued device contract');
    }
  }
  final ConnectionConfig config;
  final TimerDeviceIdentity identity;
  @override
  String toString() => 'PairedConnection([redacted])';
}

abstract interface class PairingTransport {
  Future<PairedConnection> exchange(PairingLink link, String deviceId);
  void close();
}

/// One non-retrying exchange: loss after acceptance requires a new organizer QR.
/// No bearer is sent and redirects are never followed.
class HttpPairingTransport implements PairingTransport {
  HttpPairingTransport({
    http.Client? client,
    this.timeout = const Duration(seconds: 10),
  }) : _client = client ?? http.Client();
  final http.Client _client;
  final Duration timeout;
  bool _closed = false;
  Completer<void>? _abort;
  Future<PairedConnection>? _inFlight;
  PairingLink? _activeLink;
  String? _activeDevice;
  @override
  Future<PairedConnection> exchange(PairingLink link, String deviceId) {
    if (_closed) {
      return Future.error(const OpossumException(ApiFailure.cancelled));
    }
    if (_inFlight != null &&
        (_activeLink?.origin != link.origin ||
            _activeLink?.code != link.code ||
            _activeDevice != deviceId)) {
      return Future.error(const OpossumException(ApiFailure.conflict));
    }
    _activeLink = link;
    _activeDevice = deviceId;
    return _inFlight ??= _exchange(
      link,
      uuid(deviceId),
    ).whenComplete(() => _inFlight = null);
  }

  Future<PairedConnection> _exchange(PairingLink link, String deviceId) async {
    _abort = Completer<void>();
    try {
      final request =
          http.AbortableRequest(
              'POST',
              link.origin.resolve('/api/v1/timer/pairings/exchange'),
              abortTrigger: _abort!.future,
            )
            ..followRedirects = false
            ..headers['content-type'] = 'application/json'
            ..body = jsonEncode({
              'code': link.code,
              'device_id': deviceId,
              'device_label': 'GDF HEMA Timer',
            });
      final response =
          await (() async {
            final stream = await _client.send(request), bytes = <int>[];
            await for (final chunk in stream.stream) {
              if (bytes.length + chunk.length > 65536) {
                throw const OpossumException(ApiFailure.protocol);
              }
              bytes.addAll(chunk);
            }
            return http.Response.bytes(
              bytes,
              stream.statusCode,
              headers: stream.headers,
            );
          })().timeout(
            timeout,
            onTimeout: () {
              if (!_abort!.isCompleted) _abort!.complete();
              throw const OpossumException(ApiFailure.timeout);
            },
          );
      if (_closed) throw const OpossumException(ApiFailure.cancelled);
      if (response.statusCode != 200) {
        throw OpossumException(switch (response.statusCode) {
          429 => ApiFailure.rateLimited,
          401 => ApiFailure.authentication,
          403 => ApiFailure.forbidden,
          400 || 404 => ApiFailure.rejected,
          >= 500 => ApiFailure.unavailable,
          _ => ApiFailure.protocol,
        }, code: response.statusCode == 404 ? 'PAIRING_CODE_INVALID' : null);
      }
      try {
        return PairedConnection.fromJson(
          object(jsonDecode(utf8.decode(response.bodyBytes))),
          link,
        );
      } catch (_) {
        throw const OpossumException(ApiFailure.protocol);
      }
    } on OpossumException {
      rethrow;
    } catch (_) {
      throw OpossumException(
        _closed ? ApiFailure.cancelled : ApiFailure.unavailable,
      );
    } finally {
      if (_abort != null && !_abort!.isCompleted) _abort!.complete();
    }
  }

  @override
  void close() {
    _closed = true;
    if (_abort != null && !_abort!.isCompleted) _abort!.complete();
    _client.close();
  }
}
