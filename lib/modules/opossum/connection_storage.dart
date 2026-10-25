import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_client.dart';
import 'models.dart';
import 'pending_submission.dart';

abstract class ConnectionStorage {
  bool get credentialsPersistent;
  Future<ConnectionConfig?> load();
  Future<String?> savedOrigin();
  Future<void> save(ConnectionConfig config);
  Future<void> forget();
  Future<String> deviceId();
}

/// Instantiated only on entering tournament mode. Standalone never reads tokens.
class PlatformConnectionStorage implements ConnectionStorage {
  PlatformConnectionStorage({FlutterSecureStorage? secure})
    : _secure =
          secure ??
          const FlutterSecureStorage(
            mOptions: MacOsOptions(usesDataProtectionKeychain: false),
          );
  final FlutterSecureStorage _secure;
  String? _browserToken;
  static const _key = 'opossum.connection.v1';
  static const _timeout = Duration(seconds: 6);
  @override
  bool get credentialsPersistent => !kIsWeb;
  @override
  Future<String?> savedOrigin() async =>
      (await SharedPreferences.getInstance()).getString('opossum_url');
  @override
  Future<ConnectionConfig?> load() async {
    if (!kIsWeb) {
      final saved = await _secure.read(key: _key).timeout(_timeout);
      if (saved == null) return null;
      final data = jsonDecode(saved) as Map<String, dynamic>;
      return ConnectionConfig(
        data['url'] as String,
        data['token'] as String,
        allowLocalHttp: data['local_http'] == true,
      );
    }
    final prefs = await SharedPreferences.getInstance();
    final url = prefs.getString('opossum_url');
    if (url == null || _browserToken == null) return null;
    return ConnectionConfig(
      url,
      _browserToken!,
      allowLocalHttp: prefs.getBool('opossum_local_http') ?? false,
    );
  }

  @override
  Future<void> save(ConnectionConfig config) async {
    if (!kIsWeb) {
      final encoded = jsonEncode({
        'url': config.baseUrl.toString(),
        'token': config.token,
        'local_http': config.allowLocalHttp,
      });
      await _secure.write(key: _key, value: encoded).timeout(_timeout);
      if (await _secure.read(key: _key).timeout(_timeout) != encoded) {
        throw StateError('Secure storage unavailable');
      }
    } else {
      _browserToken = config.token; // Never persist tokens in browser storage.
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('opossum_url', config.baseUrl.toString());
    await prefs.setBool('opossum_local_http', config.allowLocalHttp);
  }

  @override
  Future<void> forget() async {
    if (!kIsWeb) await _secure.delete(key: _key).timeout(_timeout);
    _browserToken = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('opossum_url');
    await prefs.remove('opossum_local_http');
  }

  @override
  Future<String> deviceId() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('opossum_device_id');
    if (saved != null) {
      try {
        return uuid(saved);
      } on FormatException {
        /* Replace invalid non-secret device metadata. */
      }
    }
    final id = newRequestId();
    await prefs.setString('opossum_device_id', id);
    return id;
  }
}
