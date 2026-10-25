// The pinned sqflite web bridge supplies its SQL/transaction protocol. We own
// durability: a complete SQLite filesystem (including rollback journals) is
// committed in ONE IndexedDB transaction before replying to any method call.
// The stock asynchronous page VFS cannot provide that acknowledgement boundary.
// ignore_for_file: implementation_imports
import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import 'package:sqflite_common_ffi_web/src/import.dart';
import 'package:sqflite_common_ffi_web/src/sqflite_ffi_impl_web.dart';
import 'package:sqflite_common_ffi_web/src/utils.dart';
import 'package:sqflite_common_ffi_web/src/web/load_sqlite_web.dart';
import 'package:sqlite3/wasm.dart';
import 'package:web/web.dart' as web;

final fs = InMemoryFileSystem();
web.IDBDatabase? storage;
Future<void>? initialization;
Future<void> persistence = Future.value();
Object? fatalStorageError;
final expiredTransactions = <int>{};
Timer? transactionWatchdog;
int? activeTransaction, databaseId;

void watchTransaction(int id) {
  transactionWatchdog?.cancel();
  transactionWatchdog = Timer(const Duration(seconds: 120), () async {
    if (activeTransaction != id) return;
    expiredTransactions.add(id);
    activeTransaction = null;
    try {
      await FfiMethodCall('execute', {
        'id': databaseId,
        'sql': 'ROLLBACK',
        'transactionId': -1,
        'inTransaction': false,
      }).handleImpl();
      await persist();
    } catch (error) {
      fatalStorageError = error;
    }
  });
}

Future<void> initialize() async {
  final request = (globalContext as web.WorkerGlobalScope).indexedDB.open(
    'gdf_timer_sqlite_v1',
    1,
  );
  final done = Completer<void>();
  request.onupgradeneeded = ((web.Event _) {
    (request.result as web.IDBDatabase).createObjectStore('filesystem');
  }).toJS;
  request.onerror = ((web.Event _) {
    done.completeError(StateError('IndexedDB unavailable'));
  }).toJS;
  request.onsuccess = ((web.Event _) {
    storage = request.result as web.IDBDatabase;
    done.complete();
  }).toJS;
  await done.future;
  final tx = storage!.transaction('filesystem'.toJS);
  final read = tx.objectStore('filesystem').get('sqlite'.toJS);
  final loaded = Completer<void>();
  read.onerror = ((web.Event _) {
    loaded.completeError(StateError('Cannot read persisted SQLite'));
  }).toJS;
  read.onsuccess = ((web.Event _) {
    final raw = read.result.dartify();
    if (raw is Map) {
      for (final entry in raw.entries) {
        // Open through the VFS to obtain its owned Uint8Buffer.
        final file = fs.xOpen(Sqlite3Filename(entry.key as String), 6).file;
        file.xWrite(Uint8List.fromList((entry.value as List).cast<int>()), 0);
        file.xClose();
      }
    }
    loaded.complete();
  }).toJS;
  await loaded.future;
  final sqlite = await WasmSqlite3.loadFromUrl(Uri.parse('sqlite3.wasm'));
  sqlite.registerVirtualFileSystem(fs, makeDefault: true);
  sqfliteFfiHandler = SqfliteFfiHandlerWeb(
    SqfliteFfiWebContextImpl(
      options: SqfliteFfiWebOptions(),
      fs: fs,
      wasmSqlite3: sqlite,
    ),
  );
}

Future<void> persist() {
  // Copy synchronously. Later SQL calls may execute while IndexedDB is writing.
  final snapshot = <String, JSUint8Array>{
    for (final entry in fs.fileData.entries)
      if (entry.value != null) entry.key: Uint8List.fromList(entry.value!).toJS,
  }.jsify();
  final operation = persistence.then((_) async {
    if (fatalStorageError != null) throw StateError('Storage requires restart');
    final tx = storage!.transaction(
      'filesystem'.toJS,
      'readwrite',
      web.IDBTransactionOptions(durability: 'strict'),
    );
    final done = Completer<void>();
    tx.oncomplete = ((web.Event _) => done.complete()).toJS;
    tx.onabort = ((web.Event _) {
      if (!done.isCompleted) {
        done.completeError(StateError('SQLite persistence aborted'));
      }
    }).toJS;
    tx.onerror = ((web.Event _) {
      // onabort is the final durability decision; prevent duplicate completion.
      if (!done.isCompleted) {
        done.completeError(StateError('SQLite persistence failed'));
      }
    }).toJS;
    tx.objectStore('filesystem').put(snapshot, 'sqlite'.toJS);
    await done.future;
  });
  persistence = operation.catchError((Object error) {
    fatalStorageError = error;
  });
  return operation;
}

Future<void> handle(web.MessageEvent event) async {
  final reply = event.ports.toDart.single;
  try {
    final raw = event.data.dartify();
    if (raw is Map && raw['kind'] == 'timer_storage_probe') {
      initialization ??= initialize();
      await initialization;
      if (fatalStorageError != null) {
        throw StateError('Storage requires restart');
      }
      reply.postMessage({'durable_shared_worker': true}.jsify());
      return;
    }
    initialization ??= initialize();
    await initialization;
    if (fatalStorageError != null) throw StateError('Storage requires restart');
    final call = FfiMethodCall.fromDataMap(raw as Map)!;
    final arguments = dataFromEncodable(call.arguments);
    if (arguments is Map &&
        expiredTransactions.contains(arguments['transactionId'])) {
      throw StateError('Local transaction expired; reload the saved draft');
    }
    // A tab closing must not close the shared SQL connection under another tab.
    if (call.method == 'closeDatabase') {
      reply.postMessage(<String, Object?>{}.jsify());
      return;
    }
    if (arguments is Map &&
        arguments['transactionId'] == activeTransaction &&
        activeTransaction != null) {
      watchTransaction(activeTransaction!);
    }
    final result = await FfiMethodCall(call.method, arguments).handleImpl();
    if (call.method == 'openDatabase' && result is Map) {
      databaseId = result['id'] as int;
    }
    if (result is Map && result['transactionId'] is int) {
      activeTransaction = result['transactionId'] as int;
      watchTransaction(activeTransaction!);
    }
    if (arguments is Map && arguments['inTransaction'] == false) {
      transactionWatchdog?.cancel();
      activeTransaction = null;
    }
    await persist();
    reply.postMessage(
      FfiMethodResponse(result: dataToEncodable(result)).toDataMap().jsify(),
    );
  } catch (error, stack) {
    reply.postMessage(
      FfiMethodResponse.fromException(error, stack).toDataMap().jsify(),
    );
  } finally {
    reply.close();
  }
}

void main() {
  // Never act as a dedicated-worker fallback: independent memory filesystems
  // could otherwise overwrite another browser tab's persisted database.
  if (!globalContext.hasProperty('onconnect'.toJS).toDart) {
    throw StateError('A SharedWorker is required');
  }
  (globalContext as web.SharedWorkerGlobalScope).onconnect =
      ((web.Event event) {
        final port = (event as web.MessageEvent).ports.toDart.single;
        port.onmessage = ((web.MessageEvent event) => unawaited(
          handle(event),
        )).toJS;
        port.start();
      }).toJS;
}
