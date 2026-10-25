// Produce an immutable application-shell manifest from the exact built files.
// Only static build artifacts enter this cache; API responses never do.
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

Future<void> main(List<String> args) async {
  final root = Directory(args.isEmpty ? 'build/web' : args.single);
  if (!File(p.join(root.path, 'main.dart.js')).existsSync()) {
    throw StateError('Build Flutter Web first');
  }
  final resources = <String, String>{};
  final files = root.listSync(recursive: true).whereType<File>().toList()
    ..sort((a, b) => a.path.compareTo(b.path));
  for (final file in files) {
    final path = p.relative(file.path, from: root.path).replaceAll('\\', '/');
    if (path == 'timer_offline_worker.js' ||
        path == 'flutter_service_worker.js' ||
        path.startsWith('api/') ||
        path.endsWith('.map')) {
      continue;
    }
    resources[path] = base64Encode(
      sha256.convert(file.readAsBytesSync()).bytes,
    );
  }
  final version = sha256.convert(utf8.encode(jsonEncode(resources))).toString();
  final code =
      '''
'use strict';
const CACHE = 'gdf-timer-shell-$version';
const RESOURCES = ${jsonEncode(resources)};
const urls = Object.keys(RESOURCES).map(path => new URL(path, self.registration.scope).href);
self.addEventListener('install', event => {
  // No skipWaiting: an update waits for existing fight windows to close.
  event.waitUntil(caches.open(CACHE).then(cache => cache.addAll(Object.entries(RESOURCES).map(([path, digest]) => new Request(new URL(path, self.registration.scope), {cache:'reload', credentials:'omit', integrity:'sha256-'+digest})))));
});
self.addEventListener('activate', event => {
  event.waitUntil((async () => {
    for (const key of await caches.keys()) if (key.startsWith('gdf-timer-shell-') && key !== CACHE) await caches.delete(key);
    await self.clients.claim();
  })());
});
self.addEventListener('fetch', event => {
  const request = event.request;
  if (request.method !== 'GET') return;
  const url = new URL(request.url);
  if (url.origin !== new URL(self.registration.scope).origin) return;
  const base = new URL(self.registration.scope);
  let key = url.href;
  if (url.href === base.href) key = new URL('index.html', base).href;
  if (!urls.includes(key)) return; // API, tokens and arbitrary URLs stay network-only.
  event.respondWith(caches.open(CACHE).then(async cache => (await cache.match(key)) || fetch(request)));
});
''';
  File(p.join(root.path, 'timer_offline_worker.js')).writeAsStringSync(code);
  stdout.writeln(
    'Prepared versioned offline shell: ${resources.length} static assets.',
  );
}
