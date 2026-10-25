import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:sqflite_common/sqlite_api.dart';
import 'api_client.dart';
import 'pending_submission.dart';
import 'tournament_store.dart';

String credentialFingerprint(String token) =>
    sha256.convert(utf8.encode(token)).toString();

/// One DB-fenced sender. Independent bouts can progress around refused entries;
/// explicit dependencies progress only after an authoritative acknowledgement.
class OutboxSync {
  OutboxSync({
    required this.store,
    required this.api,
    required this.origin,
    required this.credentialRef,
    DateTime Function()? now,
  }) : now = now ?? DateTime.now;
  final TournamentStore store;
  final OpossumClient api;
  final String origin, credentialRef;
  final DateTime Function() now;
  final String _owner = newRequestId();
  Future<void>? _inFlight;
  bool _disposed = false, _authenticationPaused = false, _storagePaused = false;
  Object? lastFailure;
  Timer? _timer;
  final List<void Function()> _listeners = [];
  void addListener(void Function() listener) => _listeners.add(listener);
  void removeListener(void Function() listener) => _listeners.remove(listener);
  void start() {
    _timer ??= Timer.periodic(
      const Duration(seconds: 5),
      (_) => unawaited(flush().catchError((Object _) {})),
    );
    unawaited(flush().catchError((Object _) {}));
  }

  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _listeners.clear();
  }

  Future<void> shutdown() async {
    dispose();
    await _inFlight;
  }

  Future<void> retry() async {
    _authenticationPaused = false;
    _storagePaused = false;
    await store.retryTransport(origin);
    await flush();
  }

  Future<void> flush() => _inFlight ??= _drain()
      .catchError((Object error) {
        lastFailure = error;
        throw error;
      })
      .whenComplete(() => _inFlight = null);
  Future<void> _drain() async {
    if (_disposed || _authenticationPaused || _storagePaused) return;
    lastFailure = null;
    var claimed = false;
    try {
      for (var count = 0; count < 20 && !_disposed; count++) {
        final entry = await store.claim(origin, _owner, now());
        if (entry == null) return;
        claimed = true;
        final id = entry.request.clientEventId;
        if (entry.credentialRef != credentialRef) {
          await store.finish(
            id,
            _owner,
            OutboxState.authentication,
            code: 'CREDENTIAL_CHANGED',
          );
          continue;
        }
        if (now()
                .toUtc()
                .difference(DateTime.parse(entry.request.submittedAt))
                .inDays >=
            29) {
          await store.finish(
            id,
            _owner,
            OutboxState.conflict,
            code: 'IDEMPOTENCY_REVIEW_REQUIRED',
          );
          continue;
        }
        try {
          // Worklist reads authenticate even for finalized nominations. Never
          // interpret disappearance from ACTIVE discovery as deletion.
          await api.worklist(entry.snapshot.nomination);
          if (entry.request.isJudge) {
            await _sendJudge(entry);
            _notify();
            continue;
          }
          final current = await api.bout(entry.request.boutId);
          if (!entry.dispatched) {
            if (current.version != entry.request.version ||
                current.a?.id != entry.request.fighterAId ||
                current.b?.id != entry.request.fighterBId) {
              await store.finish(
                id,
                _owner,
                OutboxState.conflict,
                code: 'ENTITY_VERSION_OR_PAIRING_CHANGED',
                current: current,
              );
              continue;
            }
            if (!current.writable) {
              await store.finish(
                id,
                _owner,
                OutboxState.rejected,
                code: current.blockingCode ?? 'BOUT_NOT_WRITABLE',
                current: current,
              );
              continue;
            }
          }
          // A previously dispatched request MUST reach idempotency replay even
          // when current state is completed/finalized. Do not invent a new key.
          await store.dispatched(id, _owner);
          final receipt = await api.submit(entry.request);
          await store.finish(
            id,
            _owner,
            OutboxState.acknowledged,
            receipt: receipt.toJson(),
          );
          _notify();
          try {
            await api.worklist(entry.snapshot.nomination);
          } on OpossumException {
            /* Acceptance remains durable. */
          }
        } on OpossumException catch (error) {
          final state = switch (error.kind) {
            ApiFailure.conflict => OutboxState.conflict,
            ApiFailure.rejected => OutboxState.rejected,
            ApiFailure.authentication ||
            ApiFailure.forbidden => OutboxState.authentication,
            _ =>
              entry.attempts >= 8
                  ? OutboxState.retryPaused
                  : OutboxState.pending,
          };
          final wait =
              error.retryAfter ??
              Duration(
                seconds: min(120, 2 * (1 << min(entry.attempts - 1, 6))),
              );
          await store.finish(
            id,
            _owner,
            state,
            code: error.kind == ApiFailure.rateLimited
                ? 'RATE_LIMITED'
                : error.code ?? error.kind.name,
            current: error.currentBout,
            next: [OutboxState.pending, OutboxState.retryPaused].contains(state)
                ? now().add(wait)
                : null,
          );
          _notify();
          if (state == OutboxState.authentication) _authenticationPaused = true;
          if (state == OutboxState.pending ||
              state == OutboxState.retryPaused ||
              state == OutboxState.authentication) {
            return;
          }
        }
      }
    } on DatabaseException catch (e) {
      if (![5, 6].contains((e.getResultCode() ?? 0) & 255)) {
        _storagePaused = true;
        rethrow;
      }
      // Another SQLite writer won. Its transaction remains authoritative;
      // the periodic sender tries again after the connection is free.
    } finally {
      if (claimed) {
        try {
          await store.release(_owner);
        } on DatabaseException catch (e) {
          if (![5, 6].contains((e.getResultCode() ?? 0) & 255)) rethrow;
        }
      }
    }
  }

  void _notify() {
    if (!_disposed) {
      for (final listener in List<void Function()>.of(_listeners)) {
        listener();
      }
    }
  }

  Future<void> _sendJudge(OutboxEntry original) async {
    final client = api;
    if (client is! OpossumJudgingClient) {
      throw const OpossumException(
        ApiFailure.rejected,
        code: 'JUDGING_UNAVAILABLE',
      );
    }
    late OutboxEntry entry;
    try {
      entry = await store.prepareJudge(original.request.clientEventId, _owner);
    } on StateError {
      await store.finish(
        original.request.clientEventId,
        _owner,
        OutboxState.conflict,
        code: 'JUDGING_DEPENDENCY_CHANGED',
      );
      return;
    }
    final request = entry.request;
    final current = await (client as OpossumJudgingClient).judging(
      request.boutId,
    );
    if (!entry.dispatched) {
      if (current.bout.tournamentId != request.tournamentId ||
          current.bout.nominationId != request.nominationId ||
          current.bout.a?.id != request.fighterAId ||
          current.bout.b?.id != request.fighterBId ||
          current.bout.version != request.version ||
          current.revision != request.judgingRevision) {
        await store.finish(
          request.clientEventId,
          _owner,
          OutboxState.conflict,
          code: 'ENTITY_VERSION_OR_PAIRING_CHANGED',
          current: current.bout,
        );
        return;
      }
      if (!current.judgeWrite) {
        throw const OpossumException(
          ApiFailure.forbidden,
          code: 'INSUFFICIENT_SCOPE',
        );
      }
      if (request.judgeEvent!['score_snapshot'] != null &&
          !current.scoreSnapshotWrite) {
        throw const OpossumException(
          ApiFailure.forbidden,
          code: 'INSUFFICIENT_SCOPE',
        );
      }
      // Permission to operate comes from the domain, not scheduling position.
      if (current.bout.status != 'SCHEDULED' || !current.bout.available) {
        await store.finish(
          request.clientEventId,
          _owner,
          OutboxState.rejected,
          code: 'ORGANIZER_REVIEW_REQUIRED',
          current: current.bout,
        );
        return;
      }
    }
    await store.dispatched(request.clientEventId, _owner);
    final receipt = await (client as OpossumJudgingClient).submitJudge(request);
    await store.finish(
      request.clientEventId,
      _owner,
      OutboxState.acknowledged,
      receipt: receipt.toJson(),
    );
    try {
      await api.worklist(entry.snapshot.nomination);
    } on OpossumException {
      /* Receipt is already durable. */
    }
  }
}
