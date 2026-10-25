# HEMA Scoring Machine

A lightweight, open-source **timer and scoring app** for Historical European Martial Arts (HEMA) bouts.
Designed for clarity, speed, and offline use during tournaments and sparring sessions.

---

## Features

- **Customizable Timer**
  - Set time easily (tap to edit, +/− controls)
  - Monotonic countdown with centisecond display
  - Auto-stop vibration when time runs out

- **Score Tracking**
  - Tap to increment/decrement scores
  - Prevents negative values
  - Swap fighter sides instantly

- **Warnings & Doubles**
  - Quick +/− warning counters per fighter
  - Central double-hit counter

- **Fight Log**
  - Records scores, penalties, mutual hits, corrections and timer controls
  - Viewable via drag-up “Logs” panel

- **Clean Interface**
  - Large readable fonts (`RobotoMono`)
  - Compact layout optimised for phones
  - Colour contrast for visibility

- **Haptic Feedback**
  - Vibrates when the timer ends

- **Open Source & Offline**
  - No ads or tracking; standalone needs no internet

---

## Application modes and local sessions

Choose **Standalone Timer** to score a local bout. It requires no server,
credentials, tournament or internet connection. **Opossum Tournament** is an
explicit, separate online connection flow described below. Standalone never
sends its local score or event log to Opossum.

The session controller owns immutable logical fighter A/B state. Swapping screen
sides changes the display mapping, while scores, penalties and event attribution
remain with the same fighter. Tap numbers to increment and hold to decrement.
Both additions and corrections appear in the local fight log. Tap or drag the
log bar to inspect it. Reset starts a fresh bout; holding Reset clears scoring
and penalties while keeping the current time.

The countdown uses a monotonic `Stopwatch`; UI refresh callbacks do not measure
elapsed time. Pausing excludes paused time. Losing the foreground (including a
screen-lock/background lifecycle notification) pauses the clock and shows an
interruption notice. After returning, review/adjust the remaining time and press
Start explicitly. The app does not guess elapsed time during a suspension.
There is no wake lock or guarantee of timing continuity when an operating system
fails to deliver lifecycle notifications.

Standalone bouts and logs are **in memory only**. Restarting the application opens a fresh
bout and explicitly says that previous scores/timing were not restored. The
default duration, theme, language, sound option and tutorial preference remain
stored locally. Tournament mode has the separate durable recovery described below. Leaving the timer requires confirmation before discarding its local bout.
Sound and end-of-time vibration use the existing platform plugins; unsupported
audio/haptic devices do not prevent scoring.

### Local checks

Use the Flutter version pinned by `.flutter` / the release workflow, then run:

```bash
flutter pub get --enforce-lockfile
flutter analyze
flutter test
bash tool/build_web.sh --release
```

The tests cover delayed clock refreshes, pause/resume/interruption, logical side
mapping, reversible counters and event history, reset isolation, saved settings,
mode separation, offline standalone controls, and English/Ukrainian widgets.

---

## Online Opossum workflow

Choose **Opossum Tournament**, enter the server HTTPS origin and a device bearer
token, and use **Test and save connection**. The credential needs
`tournament:read`, `bout:read` and `bout:result:write`; it may be tournament- and
nomination-bound. Discovery returns active nominations grouped by tournament.
Select the tournament, nomination, then a READY regular Round-Robin bout under
its saved stage/group/piste/configuration. A fresh bout read supplies IDs,
pairing, version and writability before the timer opens. Blocked/future
configurations are visible but cannot be selected.

Conduct the bout using the same local timer controls. Names and context remain
visible. Swapping sides preserves logical fighter A/B and does not swap the
submitted score ownership. Review the result, then deliberately confirm it.
Equal Round-Robin/tie-break scores are sent as `NORMAL` (draw). The client never manufactures AUTO WIN
or Double Loss. Tournament penalties use the separate authoritative judging API
(described below); standalone counters retain their original local behavior.
Elimination and group/stage tie-breaks are selected from **Elimination & tie-break bouts**, even without configured pistes. Selection is device-local and non-exclusive: coordinate the physical assignment with the desk before fencing. It does not reserve the bout or change the bracket. Competing results/version/pairing changes remain conflicts, never automatic overwrites. AUTO WIN is read-only. Elimination requires a decisive normal score (sudden death: 1:0 or 0:1); normal tie-break draws follow the server rules and new rounds are created at the desk.

Confirmed requests retain an immutable UUID idempotency key, client event ID,
device ID, expected A/B pairing and quoted entity version. The durable sender retries
transport failures with the **same** request and bounded backoff;
409 never overwrites a newer result. Acceptance is shown only after a validated
server receipt, followed by fresh bout/worklist reads. A refresh failure after
acceptance offers refresh, never a second result submission. Servers supporting
`Idempotency-Replayed` distinguish an original acceptance from an accepted replay;
older servers still work but cannot prove replay status.

### Durable tournament sessions and outbox

Tournament mode uses SQLite schema v2 (existing v1 queues migrate in place), separate from secure credentials. Native
storage uses sqflite (Android/iOS/macOS) or SQLite FFI (Linux/Windows), with full
synchronous transactions and a rollback/WAL journal. The local tables retain
non-secret connection/device metadata, revisioned worklist/bout caches, selected
physical piste, paired session snapshots, local event snapshots, immutable
request envelopes, dependencies, retry state, server receipts and desk-resolution
reasons. No bearer token enters SQLite; a SHA-256 credential reference prevents
replaying an uncertain operation under another API credential.

Reviewing a result flushes the saved draft. Confirmation atomically writes the
frozen session and PENDING outbox entry. SENDING is fenced by a database lease;
process recovery retries its original IDs after that lease expires (at most two
minutes). ACKNOWLEDGED requires a validated Opossum receipt written to SQLite.
Transport failures stay PENDING with persisted exponential backoff, including
failed preflight reads. After eight attempts automatic retries pause until an
operator retries explicitly; subsequent failures require another explicit retry.
Authentication also pauses sending. CONFLICT and
REJECTED retain the local result and current server evidence for explicit desk
review. HANDLED records a local review reason and is never an official acceptance
or permission to submit dependent operations. Causal dependencies require an
actual acknowledgement; independent bouts can continue around refused entries.
A unique server/bout key prevents a second local NORMAL result. Historical
corrections remain an organizer/administrator operation in Opossum.

The sender validates the original credential and reads current authoritative
work before replay. Never-sent results with changed pairing/version or blocked
lifecycle become explicit conflicts/refusals. Previously dispatched requests
still reach Opossum's idempotency lookup, even if the bout has since completed;
this recovers acceptance lost to a timeout without a second mutation. After 29
days, uncertain requests require desk review rather than risking an expired
30-day server idempotency record. Explicit retries do not bypass Retry-After.
Dispatched requests never change their If-Match version or pairing. Unsent
judging intents may bind once to their named predecessor acknowledgement as
described below.

Network loss permits explicitly labelled cached READY work and a local clock,
not new client-generated pairings or lifecycle changes. Saved/recovered results
remain labelled local until accepted. Cache timestamps/revisions show staleness.
Leaving the mode or changing assignment warns with the current pending count;
neither action nor forgetting credentials deletes evidence. Reopen the saved
server to browse/recover locally; reconnect with the original device token to
synchronize. Revoked/replaced tokens require desk review or restoring the original
authorized credential. Standalone starts a fresh independent session and never
runs the outbox.

Logical score/control changes are serialized to SQLite, with one-second running
clock checkpoints. The UI distinguishes saving, saved draft and persistence
failure; review/leave wait for the writer. After process death a recovered clock
is **paused at the last saved reading**, with an interruption warning if timing
was uncertain. No wall-clock elapsed time is invented across sleep/restart.
The operator must review/adjust timing and resume deliberately. Unsaved changes
at the instant of termination can be lost; a confirmed local result is durable.

### Authoritative tournament judging

The device additionally needs `bout:judge:write` to issue an actual REMARK,
WARNING or MUTUAL_HIT. It reads `GET /api/v1/timer/bouts/{id}/judging` and uses
`POST /api/v1/timer/bouts/{id}/judge-events`. Device scopes remain independent;
sending both score cells atomically with a hit also needs `bout:result:write`.
Missing/revoked permission never falls back to unofficial tournament counters.

The historical internal Flutter enum `PenaltyKind.warning` (Ukrainian
«Зауваження») maps to REMARK; `PenaltyKind.caution` («Попередження») maps to
WARNING. Tournament controls use explicit localized sporting terms and immutable
fighter IDs, including after a visual side swap. Standalone gestures, labels,
local counters and event history are unchanged.

Each event requires an explicit confirmation. Pending actions are durable local
evidence displayed separately from official counts. The app displays Opossum's
configured discipline and stage mutual-hit policies and their authoritative
counts/consequences; it does not calculate sanctions or continuations. A hit may
carry both current Round-Robin scores in the same transaction. An accepted
threshold event can finish a bout as Double Loss; the Timer then returns to the
worklist without sending another result.

Multiple judging intents share the existing SQLite outbox. Only the last
never-dispatched action without dependents can be locally cancelled; it remains
in history. Accepted events cannot be decremented or voided by the Timer.
Their record IDs and void history remain visible for organizer/admin review.

Offline dependent events bind once, before their first dispatch, to the exact
version/digest in their designated predecessor's durable acknowledgement.
The original intent is retained separately from that prepared request. Fresh
server state must still match that acknowledgement; unrelated edits cause a
conflict. Dispatched payloads, pairing, version, event IDs and HTTP keys never
change on retry. The schema v2 migration preserves v1 pending results and keeps
the unique result-per-bout safeguard while permitting multiple judge events.

Result confirmation waits for pending judging actions to synchronize or be
reviewed. The clock and local score draft remain usable offline, but an official
phase is never invented. On an accepted refight/sudden-death transition, timing
pauses and the previous score draft is retained until the operator explicitly
reviews and opens a new local attempt. Restart before that review preserves the
same requirement. This does not start a stage, group or server continuation.

A synthetic loopback-only rehearsal is available using the same environment
variables as the existing smoke tools:

```bash
dart run tool/opossum_judging_smoke.dart write /tmp/timer-judge.sqlite
dart run tool/opossum_judging_smoke.dart recover /tmp/timer-judge.sqlite
```

It deliberately drops an accepted response, exits without closing SQLite,
then recovers the original request and its dependent hits in another process.
Use a fresh synthetic started Round-Robin group with threshold 3 and a dedicated
test credential. It must never target a real tournament.

### Browser storage and offline build

Build Web with `bash tool/build_web.sh --release`. It compiles the pinned sqflite
protocol adapter in `tool/sqlite_worker.dart` and produces a content-addressed
static application-shell service worker. Authenticated API traffic is never
cached by that worker. Updates wait for current app windows to close; no active
fight is automatically reloaded. First installation needs a working network and
completed shell installation before tournament mode opens. A plain Flutter web
build omits the offline shell preparation and is not an offline deployment.

Web requires HTTPS (or localhost), IndexedDB, ServiceWorker and SharedWorker.
The shared SQLite connection commits its **whole filesystem including rollback
journals in one strict IndexedDB transaction before replying**; the stock
asynchronous per-page backend is deliberately not used. Separate tabs share the
SQL transaction queue and fenced outbox. An abandoned SQL transaction is rolled
back after two minutes; its old transaction ID is refused. Failed persistence
stops that worker until restart and never reports a successful local save.
Unsupported browsers fail closed for tournament mode; standalone remains usable.

Persistent browser storage is requested. If eviction protection is denied, the
app displays a warning. Do not clear site data, uninstall, use private browsing
or remove the app while results are pending: those actions can remove local
evidence on any platform. Browser tokens are memory-only; retain the original
token outside the browser for restart/reconnect. Local sporting data is not
application-encrypted; protect the OS account/device and browser origin.

Storage regression checks include real SQLite files and separate writer/reader
processes in `flutter test`. The optional Chromium check is:

```bash
# Install/use Playwright in the test environment, not the shipped application.
node tool/verify_web_storage.cjs
```

`TIMER_PLAYWRIGHT_MODULE` and `TIMER_CHROMIUM` can point at an existing local
test installation. It verifies browser process restart, simultaneous tabs,
uncommitted-transaction rollback and an actual injected IndexedDB abort using
only a disposable profile/server. No production debug hook is installed.

For a synthetic loopback Opossum server, set `OPOSSUM_TEST_BASE_URL` and
`OPOSSUM_TEST_TOKEN`, then run:

```bash
dart run tool/opossum_offline_smoke.dart write /tmp/timer-test.sqlite
dart run tool/opossum_offline_smoke.dart recover /tmp/timer-test.sqlite
```

The first drops an actual accepted response and exits without closing SQLite;
the second replays the original key and verifies the stored server result.
Use synthetic credentials/data only.

Native credentials use `flutter_secure_storage` (Keychain/Keystore/platform
secret storage). Secure storage failure is reported; there is no plaintext
fallback. Android backup is disabled to avoid restoring unusable encrypted
credentials. Linux desktop needs the plugin's libsecret development/runtime
packages and an unlocked Secret Service. macOS uses its legacy Keychain without
requiring cross-app Keychain Sharing. Browser tokens stay in memory only; they
are never saved to localStorage/shared preferences. Server URL and random device
ID are non-secret configuration. Standalone never reads credentials or creates
an Opossum network client.

HTTPS and certificate validation are the default. Redirects are refused. The
explicit development checkbox permits HTTP only for literal localhost,
127.0.0.1 or ::1, not LAN/public hosts. Android's network security configuration
has the same narrow cleartext exception. This opt-in implements the current
owner task's exception to contract §14, which otherwise forbids HTTP. No global
iOS ATS exemption is added. Flutter Web additionally needs same-origin hosting
or a separately approved CORS configuration; this change does not widen Opossum
CORS. Never disable TLS certificate checks.

### Synthetic online smoke test

`tool/opossum_online_smoke.dart` uses the real client against an isolated local
Opossum server. It refuses non-loopback hosts and selects only an active
tournament named `Synthetic Timer ...`. Set `OPOSSUM_TEST_BASE_URL` and
`OPOSSUM_TEST_TOKEN` in the test process environment, then run:

```bash
dart run tool/opossum_online_smoke.dart
```

It submits a NORMAL result, replays the identical request, and verifies the
server's stored scores, version and refreshed worklist revision. It must never
be run with a real competition credential. `test/fixtures/opossum_v1.json` was
generated from Opossum's `TimerWorklistFixture(false)`, `timerWorklistResponse`
and `timerBoutFromState`; fake HTTP/UI tests consume that actual v1 DTO shape.

### Round-Robin execution on physical pistes

Select a physical piste in the worklist. This is a device-local selection, not
an exclusive server reservation or a permanent group binding. The same piste
shows its current group and later groups/waves; one group can appear on several
pistes. Other devices have independent selection and fight state.

Active configurations, future populations, saved moves, group/stage waiting
states and remaining bouts on other pistes come from Opossum. The highlighted
recommendation is advisory: another READY bout is selectable after confirmation.
Future configurations stay visible but cannot be opened. Group starts remain
an organizer action. Opossum activates the next saved configuration only after
all current configuration bouts across its pistes resolve.

The client conditionally polls every 3 seconds on the worklist and 15 seconds
with a bout open, plus explicit refresh. Polling pauses in the background.
An open bout keeps its captured fighter IDs/version and local scores during
refresh. Server changes are flagged for review; neither refresh nor a new wave
replaces the local fight. Finish or explicitly discard it before changing piste.
Pending submissions retain their stable identifiers. Tournament sessions and
worklists use the durable recovery boundary described above.

The multi-piste regression fixture is generated by the sibling Opossum checkout
from actual scheduler v7/domain commands and validated Timer DTOs:

```bash
# From gdf-opossum:
node --import tsx scripts/create-timer-client-fixtures.ts ../gdf_hema_timer/test/fixtures/opossum_execution_v1.json.gz
```

It covers simultaneous A/B groups followed by C on both pistes, plus 8/2, 9/2,
13/3 and 17/4 fighter/piste schedules. Flutter tests consume source bout IDs,
configuration transitions and movement populations, never generate pairings.
The optional loopback-only `tool/opossum_multi_piste_smoke.dart` runs two
independently authenticated clients against a synthetic server. In addition to
`OPOSSUM_TEST_BASE_URL` and `OPOSSUM_TEST_TOKEN`, provide
`OPOSSUM_TEST_TOKEN_2`. A test harness must apply the explicit organizer
START_GROUP after its `START_NEXT_GROUP` output and acknowledge `STARTED` on
stdin. The clients themselves never request lifecycle transitions.

## Installation

### From F-Droid (recommended)
[F-Droid GDF HEMA Timer](https://f-droid.org/en/packages/com.gdf.hema_timer)

### From App Store
[App Store GDF HEMA Timer](https://apps.apple.com/us/app/gdf-hema-timer/id6754407702)

### Manual Install
1. Download the latest `.apk` from [Releases](https://github.com/kstepanovdev/gdf_hema_timer/releases)
2. Enable “Install unknown apps” on your Android device
3. Open the file to install

---

## Build from Source

You can build and sign it yourself:

```bash
git clone https://github.com/yourname/gdf_hema_timer.git
cd gdf_hema_timer
flutter pub get
flutter build apk --release
```

## Contributing
Contributions are welcome!
  1. Fork the repo
  2. Create a new branch: git checkout -b feature/my-improvement
  3. Commit your changes: git commit -am 'Add feature'
  4. Push and open a Pull Request

Operational contract fixtures can be regenerated from the Opossum workspace:

```sh
corepack pnpm run build:foundations
node --import tsx scripts/create-timer-operational-fixtures.ts ../gdf_hema_timer/test/fixtures/opossum_operational_v1.json
```

`tool/opossum_operational_smoke.dart` is a loopback-only synthetic API/SQLite rehearsal. It requires an empty temporary database, `OPOSSUM_TEST_BASE_URL`, `OPOSSUM_TEST_TOKEN` and `OPOSSUM_TEST_SECOND_TOKEN`; never use real tournaments. Server-side exclusive claims remain deferred. There is no lease to recover after device failure; the desk can authorize a replacement immediately, with version/pairing guards still mandatory.

### Secure device pairing and tournament operation

In Opossum, synchronize the tournament and open **Timer devices** on its overview.
A system administrator/superuser creates a named, tournament-scoped pairing with
optional nomination restriction, required read/result/judging permissions and an
expiry. In the Timer choose **Opossum Tournament → Scan QR**, check the displayed
HTTPS server origin, and confirm. The QR has a short-lived single-use code, never
a reusable token. The native app stores its issued credential in platform secure
storage, tests it, then discovers permitted tournaments and nominations. Restart
reuses the native credential; Web credentials intentionally last only in memory.

Camera scanning is optional on Android, iOS and macOS. If permission is denied,
use **Manual URL + device token** or paste the one-time pairing link. Linux,
Windows and Web use these manual paths; Web deliberately does not download a
third-party barcode scanner. Camera images are processed locally and not saved
or sent to Opossum. The platform camera permission is requested only for scanning.
There is no fake connection or need to type sporting UUIDs.

After connecting, select tournament, nomination and an operational assignment.
A physical piste can host different groups in later waves, while one group can
span multiple pistes. Current/future configurations, fighter movements and READY
bouts come from the server. Finish or deliberately leave the local fight before
reassignment; refresh never silently changes its fighters. Elimination/tie-break
selection is non-exclusive and must be coordinated at the organizer desk.

Use **Retry** for a temporarily unavailable server. Authentication failure may
mean expiry or revocation; check with the desk rather than replacing request
versions. **Forget connection** or re-pairing keeps all SQLite evidence. Old
confirmed requests retain their original credential and will not be submitted
under a replacement token. If that credential was revoked, an organizer must
review the retained scores/request IDs against official server history. Never
clear app data, uninstall or discard an old device with pending results. A 409
is an explicit conflict, not permission to overwrite. Standalone remains usable
without connection and never sends tournament records.

Only explicit loopback development HTTP is allowed; public/LAN connections need
HTTPS and valid certificates. Pairing does not add CORS permission: Web still
requires approved same-origin hosting or existing server configuration. A pairing
QR works once for about five minutes (server configurable). If exchange succeeded
but its response was lost, the administrator creates a new QR and revokes the
unused credential. Listings show last authenticated activity, not live presence.

Android release setup needs a compatible Flutter SDK, Android SDK/compile SDK 36,
JDK 17 and release signing configuration. The scanner sets an API 23 minimum
(Android 6; newer Flutter SDKs may set a higher minimum). Android 5 devices must
keep their earlier standalone build. The scanner uses bundled native ML Kit
by default, so first scan does not need a remote model download. The manifest
requests CAMERA but marks camera hardware optional; INTERNET remains available
for tournament mode. Build with `flutter build apk --release`. iOS/macOS need
camera privacy text/entitlements and platform signing. Native camera, secure-store
and suspend/resume behavior still need a real-device rehearsal before release.

Local validation: `flutter analyze --no-pub`, `flutter test --no-pub`, and
`bash tool/build_web.sh --release --no-pub` after dependency installation. See
Opossum's `docs/TIMER_API.md` for operator permissions and endpoint contracts.

The loopback-only `tool/opossum_pairing_smoke.dart` combines real pairing with
the existing separate-process offline rehearsal, revokes the first credential,
re-pairs, and asserts that old confirmed evidence is retained without replay.
It takes a temporary setup JSON path and an empty temporary SQLite path. The
setup contains `base` (literal 127.0.0.1 HTTP origin), `links` (two unused
pairing URIs from that same synthetic server), `prefix`
(`/api/v1/tournaments/<synthetic UUID>`) and `organizerHeaders` (the test
organizer cookie and CSRF header). Create those codes using the documented
organizer pairing API; protect/delete the temporary file after the rehearsal.
The tool refuses other origins and non-synthetic discovered tournaments.
