#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
timer_flutter="${FLUTTER_BIN:-flutter}"
timer_dart="${DART_BIN:-$(dirname "$(command -v "$timer_flutter")")/dart}"
"$timer_dart" compile js -O2 --no-source-maps tool/sqlite_worker.dart -o web/sqflite_sw.js
rm -f web/sqflite_sw.js.deps web/sqflite_sw.js.map
"$timer_flutter" build web "$@" --no-web-resources-cdn
"$timer_dart" run tool/prepare_web_offline.dart build/web
