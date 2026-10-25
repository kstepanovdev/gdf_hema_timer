import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../bout_session/bout_session_controller.dart';
import 'models.dart';
import 'session_snapshot.dart';
import 'tournament_store.dart';

/// Serializes logical changes and one-second clock checkpoints. UI updates are
/// drafts until this writer commits; confirmation explicitly awaits flush().
class SessionRecorder extends ChangeNotifier {
  SessionRecorder({
    required this.store,
    required this.controller,
    required this.origin,
    required this.nomination,
    required this.bout,
    required this.configuredMs,
    int revision = 0,
  }) : _revision = revision {
    controller.addListener(_changed);
    _checkpoint = Timer.periodic(const Duration(seconds: 1), (_) {
      if (controller.running) _save();
    });
  }
  final TournamentStore store;
  final BoutSessionController controller;
  final String origin;
  final NominationRef nomination;
  TimerBout bout;
  void updateBout(TimerBout next) {
    if (next.id != bout.id ||
        next.a?.id != bout.a?.id ||
        next.b?.id != bout.b?.id) {
      throw StateError('Recovered bout identity changed');
    }
    bout = next;
    checkpoint();
  }

  final int configuredMs;
  int _revision;
  int get revision => _revision;
  String? _logical;
  Timer? _checkpoint;
  Future<void> _tail = Future.value();
  Object? error;
  int pending = 0;
  bool _disposed = false;
  SessionSnapshot snapshot() => SessionSnapshot(
    origin: origin,
    nomination: nomination,
    bout: bout,
    session: controller.session,
    remainingMs: controller.remaining.inMilliseconds,
    wasRunning: controller.running,
    timingUncertain: controller.interrupted,
    events: controller.fightLog.events,
    savedAt: DateTime.now().toUtc(),
    configuredMs: configuredMs,
  );
  void _changed() {
    final key = jsonEncode({
      's': sessionJson(controller.session),
      'events': controller.fightLog.events.length,
      'last_event': controller.fightLog.events.isEmpty
          ? null
          : eventJson(controller.fightLog.events.last),
      'running': controller.running,
      'interrupted': controller.interrupted,
    });
    if (key == _logical) return;
    _logical = key;
    _save();
  }

  void checkpoint() => _save();
  void _save() {
    if (_disposed) return;
    final value = snapshot();
    pending++;
    notifyListeners();
    _tail = _tail
        .then((_) async {
          _revision = await store.saveDraft(value, _revision);
          error = null;
        })
        .catchError((Object e) {
          error = e;
        })
        .whenComplete(() {
          pending--;
          if (!_disposed) notifyListeners();
        });
  }

  Future<void> flush() async {
    await _tail;
    if (error != null) throw StateError('Session not persisted');
  }

  @override
  void dispose() {
    _disposed = true;
    _checkpoint?.cancel();
    controller.removeListener(_changed);
    super.dispose();
  }
}
