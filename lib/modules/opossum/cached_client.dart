import 'api_client.dart';
import 'models.dart';
import 'pending_submission.dart';
import 'tournament_store.dart';
import 'judging.dart';

bool isTransportFailure(OpossumException e) => [
  ApiFailure.unavailable,
  ApiFailure.timeout,
  ApiFailure.cancelled,
].contains(e.kind);

/// Cache is a labelled historical server snapshot, never a local sporting engine.
class CachedOpossumClient implements OpossumClient, OpossumJudgingClient {
  CachedOpossumClient({
    required this.network,
    required this.store,
    required this.origin,
  });
  final OpossumClient network;
  final TournamentStore store;
  final String origin;
  bool offline = false;
  DateTime? cachedAt;
  @override
  Future<List<NominationRef>> discover() async {
    try {
      final result = await network.discover();
      await store.cacheDiscovery(origin, result);
      offline = false;
      return result;
    } on OpossumException catch (e) {
      if (!isTransportFailure(e)) rethrow;
      final saved = await store.metadata('discovery|$origin');
      if (saved == null) rethrow;
      offline = true;
      return array(
        saved['nominations'],
      ).map((e) => NominationRef.fromJson(object(e))).toList();
    }
  }

  @override
  Future<TimerWorklist> worklist(NominationRef nomination) async {
    final key = 'work|$origin|${nomination.tournamentId}|${nomination.id}';
    try {
      final result = await network.worklist(nomination),
          now = DateTime.now().toUtc();
      await store.cache(key, result.toJson(), result.serverRevision, now);
      offline = false;
      cachedAt = now;
      return result;
    } on OpossumException catch (e) {
      if (!isTransportFailure(e)) rethrow;
      final saved = await store.cached(key);
      if (saved == null) rethrow;
      offline = true;
      cachedAt = saved.savedAt;
      return TimerWorklist.fromJson(saved.body);
    }
  }

  @override
  Future<TimerBout> bout(String id) async {
    try {
      final result = await network.bout(id);
      await store.cache(
        'bout|$origin|$id',
        result.toJson(),
        result.serverRevision,
        DateTime.now().toUtc(),
      );
      return result;
    } on OpossumException catch (e) {
      if (!isTransportFailure(e)) rethrow;
      var saved = await store.cached('bout|$origin|$id');
      final fromWorklist = await store.cachedBout(origin, id);
      if (fromWorklist != null &&
          (saved == null ||
              BigInt.parse(
                    TimerBout.fromJson(fromWorklist.body).serverRevision,
                  ) >
                  BigInt.parse(
                    TimerBout.fromJson(saved.body).serverRevision,
                  ))) {
        saved = fromWorklist;
      }
      if (saved == null) rethrow;
      offline = true;
      cachedAt = saved.savedAt;
      return TimerBout.fromJson(saved.body);
    }
  }

  @override
  Future<AcceptedResult> submit(PendingSubmission request) =>
      network.submit(request);
  OpossumJudgingClient get _judging {
    final client = network;
    if (client is! OpossumJudgingClient) {
      throw const OpossumException(
        ApiFailure.rejected,
        code: 'JUDGING_UNAVAILABLE',
      );
    }
    return client as OpossumJudgingClient;
  }

  @override
  Future<JudgingState> judging(String id) async {
    final key = 'judging|$origin|$id';
    try {
      final result = await _judging.judging(id);
      await store.cache(
        key,
        result.toJson(),
        result.bout.serverRevision,
        DateTime.now().toUtc(),
      );
      offline = false;
      return result;
    } on OpossumException catch (e) {
      if (!isTransportFailure(e)) rethrow;
      final saved = await store.cached(key);
      if (saved == null) rethrow;
      offline = true;
      cachedAt = saved.savedAt;
      return JudgingState.fromJson(saved.body);
    }
  }

  @override
  Future<JudgingReceipt> submitJudge(PendingSubmission request) =>
      _judging.submitJudge(request);
  @override
  void close() => network.close();
}

/// Deliberate cache browsing without credentials (e.g. a restarted browser).
/// It cannot claim a connection or submit. Reconnect using the original token.
class DisconnectedClient implements OpossumClient, OpossumJudgingClient {
  @override
  Future<JudgingState> judging(String id) =>
      throw const OpossumException(ApiFailure.unavailable);
  @override
  Future<JudgingReceipt> submitJudge(PendingSubmission request) =>
      throw const OpossumException(ApiFailure.authentication);
  @override
  Future<List<NominationRef>> discover() =>
      throw const OpossumException(ApiFailure.unavailable);
  @override
  Future<TimerWorklist> worklist(NominationRef n) =>
      throw const OpossumException(ApiFailure.unavailable);
  @override
  Future<TimerBout> bout(String id) =>
      throw const OpossumException(ApiFailure.unavailable);
  @override
  Future<AcceptedResult> submit(PendingSubmission request) =>
      throw const OpossumException(ApiFailure.authentication);
  @override
  void close() {}
}
