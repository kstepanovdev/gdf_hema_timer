import 'dart:async';
import 'package:flutter/foundation.dart';
import 'api_client.dart';
import 'models.dart';

/// A device selects a physical piste, never a permanent group assignment.
/// Refresh replaces only server projections, not the captured local fight.
class WorklistController extends ChangeNotifier {
  WorklistController({required this.api, required this.nomination});
  final OpossumClient api;
  final NominationRef nomination;
  TimerWorklist? work;
  OpossumException? error;
  String? selectedPisteId;
  TimerBout? activeBout;
  TimerBout? refreshedBout;
  bool loading = false;
  bool _disposed = false, _polling = false;
  Timer? _timer;
  Future<void>? _inFlight;
  PisteWorklist? get selected => work?.piste(selectedPisteId);
  bool get activeChanged {
    final a = activeBout, b = refreshedBout;
    return a != null &&
        b != null &&
        (a.version != b.version ||
            a.a?.id != b.a?.id ||
            a.b?.id != b.b?.id ||
            a.groupId != b.groupId ||
            a.pisteId != b.pisteId ||
            a.configurationId != b.configurationId ||
            !b.writable);
  }

  void startPolling() {
    _polling = true;
    unawaited(refresh());
  }

  void stopPolling() {
    _polling = false;
    _timer?.cancel();
  }

  void _schedule() {
    _timer?.cancel();
    if (_polling && !_disposed) {
      _timer = Timer(
        Duration(seconds: activeBout == null ? 3 : 15),
        () => unawaited(refresh()),
      );
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> refresh() => _inFlight ??= _refresh().whenComplete(() {
    _inFlight = null;
    _schedule();
  });
  Future<void> _refresh() async {
    loading = true;
    _notify();
    final captured = activeBout;
    try {
      final next = await api.worklist(nomination);
      if (next.tournamentId != nomination.tournamentId ||
          next.nominationId != nomination.id) {
        throw const OpossumException(ApiFailure.protocol);
      }
      final fresh = captured == null ? null : await api.bout(captured.id);
      if (_disposed) return;
      if (work != null &&
          BigInt.parse(next.serverRevision) <
              BigInt.parse(work!.serverRevision)) {
        throw const OpossumException(ApiFailure.protocol);
      }
      // A removed piste requires an explicit new selection. Never switch a
      // device to another group/piste while its captured bout is still open.
      if (captured != null && identical(activeBout, captured)) {
        if (fresh!.id != captured.id ||
            fresh.tournamentId != captured.tournamentId ||
            fresh.nominationId != captured.nominationId) {
          throw const OpossumException(ApiFailure.protocol);
        }
        refreshedBout = fresh;
      }
      work = next;
      selectedPisteId ??= next.pistes.firstOrNull?.id;
      error = null;
    } on OpossumException catch (failure) {
      if (!_disposed) error = failure;
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

  bool selectPiste(String id) {
    if (activeBout != null || work?.piste(id) == null) return false;
    selectedPisteId = id;
    _notify();
    return true;
  }

  bool begin(TimerBout bout) {
    if (activeBout != null ||
        error != null ||
        !bout.writable ||
        (!bout.operational && bout.pisteId != selectedPisteId) ||
        bout.tournamentId != nomination.tournamentId ||
        bout.nominationId != nomination.id) {
      return false;
    }
    activeBout = bout;
    refreshedBout = bout;
    _schedule();
    _notify();
    return true;
  }

  bool restoreDraft(TimerBout captured) {
    if (activeBout != null ||
        captured.tournamentId != nomination.tournamentId ||
        captured.nominationId != nomination.id) {
      return false;
    }
    activeBout = captured;
    refreshedBout = null;
    if (!captured.operational) selectedPisteId = captured.pisteId;
    _schedule();
    _notify();
    return true;
  }

  void end() {
    activeBout = null;
    refreshedBout = null;
    _schedule();
    _notify();
  }

  /// Only a persisted acknowledgement of this device's operation may rebase
  /// the captured bout. Ordinary polling still detects external changes.
  void acknowledgeJudging(TimerBout next) {
    final old = activeBout;
    if (old == null ||
        old.id != next.id ||
        old.a?.id != next.a?.id ||
        old.b?.id != next.b?.id ||
        old.configurationId != next.configurationId ||
        old.pisteId != next.pisteId) {
      throw StateError('Acknowledged assignment changed');
    }
    activeBout = next;
    refreshedBout = next;
    _notify();
  }

  @override
  void dispose() {
    _disposed = true;
    stopPolling();
    super.dispose();
  }
}
