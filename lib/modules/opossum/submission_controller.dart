import 'package:flutter/foundation.dart';
import '../bout_session/bout_session.dart';
import 'api_client.dart';
import 'models.dart';
import 'pending_submission.dart';
import 'tournament_store.dart';
import 'outbox_sync.dart';
import 'session_snapshot.dart';

/// One reviewed, frozen result. Retrying never re-reads mutable score controls.
class SubmissionController extends ChangeNotifier {
  SubmissionController({
    required this.api,
    required this.repository,
    required this.origin,
    required this.nomination,
    required this.bout,
    required this.session,
    required this.deviceId,
    this.outbox,
    this.snapshot,
    this.credentialRef,
    this.expectedDraftRevision,
  });
  final OpossumClient api;
  final PendingSubmissionRepository repository;
  final String origin, deviceId;
  final OutboxSync? outbox;
  final SessionSnapshot? snapshot;
  final String? credentialRef;
  final int? expectedDraftRevision;
  bool savedLocally = false;
  final NominationRef nomination;
  final TimerBout bout;
  final BoutSession session;
  PendingSubmission? request;
  AcceptedResult? receipt;
  TimerBout? authoritativeBout;
  TimerWorklist? authoritativeWorklist;
  OpossumException? error;
  SubmissionState state = SubmissionState.pending;
  bool refreshFailed = false;
  int attempts = 0;
  bool _disposed = false;
  Future<void>? _inFlight;
  DateTime? retryAt;
  bool get sending => _inFlight != null || state == SubmissionState.sending;
  bool get canRetry => [
    SubmissionState.uncertain,
    SubmissionState.authentication,
    SubmissionState.rateLimited,
  ].contains(state);
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> confirm() {
    if (receipt != null || (request != null && !canRetry)) {
      return _inFlight ?? Future.value();
    }
    if (retryAt != null && DateTime.now().isBefore(retryAt!)) {
      return Future.value();
    }
    return _inFlight ??= _send().whenComplete(() {
      _inFlight = null;
      _notify();
    });
  }

  Future<void> _send() async {
    if (repository is TournamentStore) {
      await _sendDurable(repository as TournamentStore);
      return;
    }
    error = null;
    request ??= PendingSubmission.confirm(
      origin: origin,
      bout: bout,
      session: session,
      deviceId: deviceId,
    );
    state = SubmissionState.sending;
    _notify();
    try {
      try {
        await repository.save(request!);
        await repository.setState(request!.clientEventId, state);
      } catch (_) {
        throw const OpossumException(ApiFailure.storage);
      }
      attempts++;
      receipt = await api.submit(request!);
      state = SubmissionState.accepted;
      try {
        await repository.setState(request!.clientEventId, state);
      } catch (_) {
        error = const OpossumException(ApiFailure.storage);
      }
      _notify();
      await refresh();
    } on OpossumException catch (failure) {
      error = failure;
      state = switch (failure.kind) {
        ApiFailure.authentication => SubmissionState.authentication,
        ApiFailure.forbidden => SubmissionState.forbidden,
        ApiFailure.conflict => SubmissionState.conflict,
        ApiFailure.rejected => SubmissionState.rejected,
        ApiFailure.rateLimited => SubmissionState.rateLimited,
        _ => SubmissionState.uncertain,
      };
      retryAt = failure.retryAfter == null
          ? null
          : DateTime.now().add(failure.retryAfter!);
      try {
        await repository.setState(request!.clientEventId, state);
      } catch (_) {
        /* Original request and error remain in memory. */
      }
      _notify();
    }
  }

  Future<void> _sendDurable(TournamentStore store) async {
    error = null;
    try {
      request ??= PendingSubmission.confirm(
        origin: origin,
        bout: bout,
        session: session,
        deviceId: deviceId,
      );
      if (snapshot == null || credentialRef == null) {
        throw StateError('Missing durable confirmation context');
      }
      final wasSaved = savedLocally;
      await store.confirm(
        request!,
        snapshot!,
        credentialRef!,
        expectedDraftRevision: expectedDraftRevision,
      );
      savedLocally = true;
      state = SubmissionState.uncertain;
      _notify();
      if (wasSaved) {
        await outbox?.retry();
      } else {
        await outbox?.flush();
      }
      final entry = (await store.entry(request!.clientEventId))!;
      attempts = entry.attempts;
      state = switch (entry.state) {
        OutboxState.acknowledged => SubmissionState.accepted,
        OutboxState.conflict => SubmissionState.conflict,
        OutboxState.rejected => SubmissionState.rejected,
        OutboxState.authentication => SubmissionState.authentication,
        _ => SubmissionState.uncertain,
      };
      if (entry.receipt != null) {
        receipt = AcceptedResult.fromJson(
          entry.receipt!,
          replayed: entry.receipt!['replayed'] as bool?,
        );
        await refresh();
      } else if (entry.errorCode != null) {
        error = OpossumException(
          switch (entry.state) {
            OutboxState.conflict => ApiFailure.conflict,
            OutboxState.rejected => ApiFailure.rejected,
            OutboxState.authentication => ApiFailure.authentication,
            _ => ApiFailure.unavailable,
          },
          code: entry.errorCode,
          currentBout: entry.serverBout,
        );
      }
    } catch (_) {
      error = const OpossumException(ApiFailure.localPersistence);
      state = SubmissionState.uncertain;
    }
    _notify();
  }

  Future<void> refresh() async {
    if (receipt == null) return;
    try {
      authoritativeBout = await api.bout(bout.id);
      authoritativeWorklist = await api.worklist(nomination);
      refreshFailed = false;
    } on OpossumException {
      refreshFailed = true;
    }
    _notify();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
