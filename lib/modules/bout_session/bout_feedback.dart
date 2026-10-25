import 'package:audioplayers/audioplayers.dart';
import 'package:vibration/vibration.dart';
import '../settings/settings_storage.dart';

/// Platform effects stay outside scoring and measured-time state.
abstract class BoutFeedback {
  Future<void> prepare();
  Future<void> mutualHit();
  Future<void> timeExpired();
  Future<void> dispose();
}

class StandaloneBoutFeedback implements BoutFeedback {
  final AudioPlayer _player = AudioPlayer();
  bool _ready = false;
  bool _disposed = false;

  @override
  Future<void> prepare() async {
    try {
      await _player.setReleaseMode(ReleaseMode.stop);
      if (_disposed) return;
      await _player.setSource(AssetSource('sounds/bruh.mp3'));
      _ready = !_disposed;
    } catch (_) {
      // A missing audio device must never prevent local scoring.
    }
  }

  @override
  Future<void> mutualHit() async {
    if (!_ready || _disposed || !yehorsSpecialEnabled.value) return;
    try {
      await _player.seek(Duration.zero);
      if (!_disposed) await _player.resume();
    } catch (_) {
      // Sound is optional; the counter is already recorded locally.
    }
  }

  @override
  Future<void> timeExpired() async {
    try {
      if (!_disposed && await Vibration.hasVibrator() && !_disposed) {
        await Vibration.vibrate(duration: 1000, amplitude: 255);
      }
    } catch (_) {
      // Vibration may be unsupported on desktop/web.
    }
  }

  @override
  Future<void> dispose() async {
    _disposed = true;
    try {
      await _player.dispose();
    } catch (_) {
      // Some unsupported platforms have no audio channel to dispose.
    }
  }
}
