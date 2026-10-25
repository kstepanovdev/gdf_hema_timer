import 'dart:async';
import 'package:flutter/foundation.dart';
import '../bout_session/bout_session_controller.dart';
import '../bout_session/bout_session.dart';
import 'api_client.dart';
import 'cached_client.dart';
import 'judging.dart';
import 'models.dart';
import 'outbox_sync.dart';
import 'pending_submission.dart';
import 'session_recorder.dart';
import 'session_snapshot.dart';
import 'tournament_store.dart';

/// Tournament-only coordinator. Local pending evidence never derives official
/// warnings, Double Loss, disqualification, refights or a sudden-death phase.
class JudgingController extends ChangeNotifier {
  JudgingController({
    required this.api,
    required this.session,
    required this.initialBout,
    required this.origin,
    required this.deviceId,
    this.store,
    this.sync,
    this.recorder,
    this.credentialRef,
    required this.snapshot,
    this.onAcknowledged,
  });
  final OpossumClient api;
  final BoutSessionController session;
  final TimerBout initialBout;
  final String origin, deviceId;
  final TournamentStore? store;
  final OutboxSync? sync;
  final SessionRecorder? recorder;
  final String? credentialRef;
  final SessionSnapshot Function() snapshot;
  final void Function(TimerBout)? onAcknowledged;
  JudgingState? state;
  JudgingState? competingState;
  List<OutboxEntry> entries = [];
  OpossumException? error;
  bool busy = false, loading = false, changed = false, _disposed = false;
  bool continuationReview = false;
  PendingSubmission? unsavedRequest;
  SessionSnapshot? _unsavedSnapshot;
  bool _unsavedReview = false;
  Future<void>? _refreshing;
  Timer? _poll;
  String? _lastAcknowledged;
  bool? _lastSide;
  String? _lastScores;
  void _sessionChanged() {
    final scores = '${session.session.a.score}:${session.session.b.score}';
    if (_lastSide != session.session.leftIsA || _lastScores != scores) {
      _lastSide = session.session.leftIsA;
      _lastScores = scores;
      _notify();
    }
  }

  bool get offline =>
      api is CachedOpossumClient && (api as CachedOpossumClient).offline;
  TimerBout get bout => state?.bout ?? initialBout;
  bool get terminal => state != null && state!.bout.status != 'SCHEDULED';
  List<OutboxEntry> get pending => entries.where((e) => e.unresolved).toList();
  bool get blocked =>
      changed ||
      [
        ApiFailure.authentication,
        ApiFailure.forbidden,
        ApiFailure.conflict,
      ].contains(error?.kind) ||
      entries.any(
        (e) => [
          OutboxState.conflict,
          OutboxState.rejected,
          OutboxState.authentication,
          OutboxState.handled,
        ].contains(e.state),
      );
  bool get decisiveScoreValid {
    if (bout.stageType != 'SINGLE_ELIMINATION') return true;
    final a = session.session.a.score, b = session.session.b.score;
    return state?.phase == 'SUDDEN_DEATH'
        ? (a == 1 && b == 0) || (a == 0 && b == 1)
        : a != b;
  }

  bool get canReview =>
      unsavedRequest == null &&
      !busy &&
      !blocked &&
      pending.isEmpty &&
      !terminal &&
      !continuationReview &&
      decisiveScoreValid;
  bool canIssue(JudgeEventKind kind, String? fighterId) {
    final current = state;
    if (current == null ||
        unsavedRequest != null ||
        busy ||
        blocked ||
        terminal ||
        continuationReview ||
        store == null ||
        recorder == null ||
        credentialRef == null ||
        !current.judgeWrite) {
      return false;
    }
    if ([ApiFailure.protocol, ApiFailure.rejected].contains(error?.kind)) {
      return false;
    }
    final available = current.availability(kind, fighterId);
    return available.available ||
        (kind == JudgeEventKind.mutualHit &&
            available.reason == 'JUDGING_SCORES_REQUIRED' &&
            current.scoreSnapshotWrite);
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> start() async {
    _lastSide = session.session.leftIsA;
    session.addListener(_sessionChanged);
    sync?.addListener(_syncChanged);
    _poll = Timer.periodic(
      const Duration(seconds: 5),
      (_) => unawaited(refresh()),
    );
    await refresh();
  }

  void _syncChanged() => unawaited(refresh());
  Future<void> reloadLocal() async {
    await _readEntries();
    _notify();
  }

  Future<void> refresh() =>
      _refreshing ??= _refresh().whenComplete(() => _refreshing = null);
  Future<void> _readEntries() async {
    if (store == null || _disposed) return;
    entries = (await store!.entries(origin: origin))
        .where((e) => e.request.isJudge && e.request.boutId == initialBout.id)
        .toList();
    for (final entry in entries.reversed) {
      if (entry.state == OutboxState.acknowledged && entry.receipt != null) {
        if (_lastAcknowledged != entry.request.clientEventId) {
          final receipt = JudgingReceipt.fromJson(entry.receipt!);
          if (state == null ||
              receipt.state.bout.version >= state!.bout.version) {
            _apply(receipt.state, accepted: true);
          }
          _lastAcknowledged = entry.request.clientEventId;
        }
        break;
      }
    }
  }

  Future<void> _refresh() async {
    loading = true;
    _notify();
    try {
      await _readEntries();
      final client = api;
      if (client is! OpossumJudgingClient) {
        throw const OpossumException(
          ApiFailure.rejected,
          code: 'JUDGING_UNAVAILABLE',
        );
      }
      final next = await (client as OpossumJudgingClient).judging(
        initialBout.id,
      );
      if (_disposed) return;
      await _readEntries(); // A sender may have acknowledged while GET was in flight.
      if (!_samePairing(next.bout)) {
        changed = true;
        throw const OpossumException(
          ApiFailure.conflict,
          code: 'PAIRING_CHANGED',
        );
      }
      final known = state?.bout ?? initialBout;
      if (next.bout.version < known.version) {
        return; // Cached/older HTTP responses cannot undo an acknowledgement.
      }
      if (next.bout.version != known.version) {
        if (pending.isEmpty) {
          changed = true;
          competingState = next;
          session.pause();
          error = OpossumException(
            ApiFailure.conflict,
            code: 'ENTITY_VERSION_CHANGED',
            currentBout: next.bout,
          );
          return; // Keep the captured local scores and pairing for explicit review.
        }
        // Pending requests retain their captured preconditions. Only their
        // acknowledged receipts can move this local session to another version.
        if (pending.isNotEmpty) return;
      }
      _apply(next);
      error = null;
    } on OpossumException catch (e) {
      if (!_disposed) error = e;
    } catch (_) {
      if (!_disposed) {
        error = const OpossumException(ApiFailure.localPersistence);
      }
    } finally {
      if (!_disposed) {
        loading = false;
        _notify();
      }
    }
  }

  bool _samePairing(TimerBout b) =>
      b.id == initialBout.id &&
      b.tournamentId == initialBout.tournamentId &&
      b.nominationId == initialBout.nominationId &&
      b.stageId == initialBout.stageId &&
      b.configurationId == initialBout.configurationId &&
      b.pisteId == initialBout.pisteId &&
      b.a?.id == session.session.a.id &&
      b.b?.id == session.session.b.id;
  void _apply(JudgingState next, {bool accepted = false}) {
    if (_disposed) return;
    if (!_samePairing(next.bout)) {
      throw const OpossumException(
        ApiFailure.conflict,
        code: 'PAIRING_CHANGED',
      );
    }
    final previous = state;
    state = next;
    final current = session.session;
    final a = next.fighter(current.a.id), b = next.fighter(current.b.id);
    final capturedHits = initialBout.toJson()['mutual_hits'];
    final previousPhase =
        previous?.phase ?? (capturedHits is Map ? capturedHits['phase'] : null);
    final previousAttempt =
        previous?.attempt ??
        (capturedHits is Map ? capturedHits['attempt'] : null);
    final continuation =
        previousPhase != next.phase || previousAttempt != next.attempt;
    final terminal = next.bout.status != 'SCHEDULED';
    if (continuation && !terminal) continuationReview = true;
    session.applyAuthoritativeSession(
      current.copyWith(
        a: current.a.copyWith(
          warning: a.remarks,
          caution: a.warnings,
          score: terminal ? next.bout.scoreA ?? 0 : null,
        ),
        b: current.b.copyWith(
          warning: b.remarks,
          caution: b.warnings,
          score: terminal ? next.bout.scoreB ?? 0 : null,
        ),
        mutualHits: next.bout.effectiveHits,
      ),
      pauseClock: continuation || terminal || changed,
    );
    if (accepted) {
      if (!continuationReview) recorder?.updateBout(next.bout);
      onAcknowledged?.call(next.bout);
    }
  }

  /// Confirm a local draft reset only after the server started a continuation.
  /// Until then the previous draft remains durable, including across restart.
  void acceptContinuation() {
    if (!continuationReview ||
        state == null ||
        terminal ||
        pending.isNotEmpty ||
        blocked) {
      return;
    }
    session.pause();
    session.setScore(DisplaySide.left, 0);
    session.setScore(DisplaySide.right, 0);
    continuationReview = false;
    recorder?.updateBout(state!.bout);
    _notify();
  }

  Future<void> confirm(
    JudgeEventKind kind, {
    String? fighterId,
    JudgingState? basis,
    SessionSnapshot? captured,
  }) async {
    if (busy ||
        unsavedRequest != null ||
        store == null ||
        recorder == null ||
        credentialRef == null ||
        (basis == null && !canIssue(kind, fighterId))) {
      return;
    }
    final current = basis ?? state!;
    _unsavedSnapshot = captured ?? snapshot();
    unsavedRequest = PendingSubmission.judge(
      origin: origin,
      judging: current,
      session: _unsavedSnapshot!.session,
      kind: kind,
      fighterId: fighterId,
      deviceId: deviceId,
    );
    _unsavedReview =
        blocked ||
        terminal ||
        state?.bout.version != current.bout.version ||
        state?.revision != current.revision;
    await retryLocalSave();
  }

  Future<void> retryLocalSave() async {
    if (busy || unsavedRequest == null) return;
    busy = true;
    _notify();
    try {
      await recorder!.flush();
      await store!.confirmJudge(
        unsavedRequest!,
        _unsavedSnapshot!,
        credentialRef!,
        reviewRequired: _unsavedReview,
      );
      unsavedRequest = null;
      _unsavedSnapshot = null;
      await _readEntries();
      error = null;
      if (sync != null) {
        unawaited(
          sync!.flush().catchError((Object _) {
            _notify();
          }),
        );
      }
    } catch (_) {
      error = const OpossumException(ApiFailure.localPersistence);
    } finally {
      busy = false;
      _notify();
    }
  }

  Future<void> cancelUnsent(OutboxEntry entry) async {
    if (busy) return;
    busy = true;
    try {
      await store!.cancelUnsentJudge(entry.request.clientEventId);
      await _readEntries();
      error = null;
    } catch (_) {
      error = const OpossumException(
        ApiFailure.rejected,
        code: 'ORGANIZER_REVIEW_REQUIRED',
      );
    } finally {
      busy = false;
      _notify();
    }
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _poll?.cancel();
    session.removeListener(_sessionChanged);
    sync?.removeListener(_syncChanged);
    super.dispose();
  }
}
