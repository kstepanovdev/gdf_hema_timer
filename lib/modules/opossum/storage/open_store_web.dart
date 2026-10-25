import 'dart:async';
import 'dart:js_interop';
import 'package:web/web.dart' as web;
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import '../tournament_store.dart';

@JS('timerOfflineReady')
external JSPromise<JSBoolean> get _offlineReady;

Future<TournamentStore> openTournamentStore() async {
  if (!(await _offlineReady.toDart.timeout(
    const Duration(seconds: 30),
  )).toDart) {
    throw StateError('Build/install the offline application shell first');
  }
  var protected = false;
  try {
    protected = (await web.window.navigator.storage.persist().toDart.timeout(
      const Duration(seconds: 5),
    )).toDart;
  } catch (_) {
    /* Show the browser eviction limitation explicitly. */
  }
  // Explicitly create/probe the exact shared backend. The stock factory may
  // fall back to a per-tab worker; our worker refuses that unsafe fallback.
  final worker = web.SharedWorker(
    'sqflite_sw.js'.toJS,
    'sqflite_common_ffi_web'.toJS,
  );
  final channel = web.MessageChannel();
  final ready = Completer<void>();
  channel.port1.onmessage = ((web.MessageEvent event) {
    final data = event.data.dartify();
    if (data is Map && data['durable_shared_worker'] == true) {
      ready.complete();
    } else {
      ready.completeError(StateError('Durable storage probe failed'));
    }
  }).toJS;
  worker.port.postMessage(
    {'kind': 'timer_storage_probe'}.jsify(),
    [channel.port2].toJS,
  );
  try {
    await ready.future.timeout(const Duration(seconds: 30));
    return await TournamentStore.open(
      databaseFactoryFfiWeb,
      'opossum-v1.sqlite',
      writeAheadLog: false,
      singleInstance: true,
      evictionProtected: protected,
    ).timeout(const Duration(seconds: 30));
  } finally {
    channel.port1.close();
    worker.port.close();
  }
}
