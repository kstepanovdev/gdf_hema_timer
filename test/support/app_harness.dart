import 'package:audioplayers/audioplayers.dart';
import 'package:audioplayers_platform_interface/audioplayers_platform_interface.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gdf_hema_timer/main.dart';
import 'package:gdf_hema_timer/modules/settings/settings_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vibration_platform_interface/vibration_platform_interface.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:wakelock_plus_platform_interface/wakelock_plus_platform_interface.dart';

/// What the app asked of the native plugins during a test.
class PlatformLog {
  /// Each wakelock toggle, in order (`true` = keep the screen on).
  final wakelock = <bool>[];

  /// Duration (ms) of each vibration.
  final vibrations = <int>[];

  /// Method names sent to the audio player.
  final audio = <String>[];
}

class _FakeWakelock extends WakelockPlusPlatformInterface {
  _FakeWakelock(this.log);
  final List<bool> log;

  @override
  Future<void> toggle({required bool enable}) async => log.add(enable);

  @override
  Future<bool> get enabled async => log.isNotEmpty && log.last;
}

class _FakeVibration extends VibrationPlatform {
  _FakeVibration(this.log);
  final List<int> log;

  @override
  Future<bool> hasVibrator() async => true;

  @override
  Future<void> vibrate({
    int duration = 500,
    List<int> pattern = const [],
    int repeat = -1,
    List<int> intensities = const [],
    int amplitude = -1,
    double sharpness = 0.5,
  }) async => log.add(duration);
}

class _FakeGlobalAudio extends GlobalAudioplayersPlatformInterface {
  @override
  Future<void> init() async {}

  @override
  Future<void> setGlobalAudioContext(AudioContext ctx) async {}

  @override
  Future<void> emitGlobalLog(String message) async {}

  @override
  Future<void> emitGlobalError(String code, String message) async {}

  @override
  Stream<GlobalAudioEvent> getGlobalEventStream() => const Stream.empty();
}

/// Skips copying the sound asset to a temp file.
class _NoAudioCache extends AudioCache {
  @override
  Future<Uri> load(String fileName) async => Uri.parse('file:///$fileName');
}

/// Fakes the native plugins, seeds preferences, and pumps the app on a
/// phone-sized screen. The launch tutorial is off unless [prefs] says so.
Future<PlatformLog> pumpApp(
  WidgetTester tester, {
  Map<String, Object> prefs = const {},
}) async {
  final log = PlatformLog();
  wakelockPlusPlatformInstance = _FakeWakelock(log.wakelock);
  VibrationPlatform.instance = _FakeVibration(log.vibrations);
  AudioCache.instance = _NoAudioCache();
  // A fresh instance makes the player re-run its one-time global init in this
  // test's fake-time zone; one left over from a previous test never resolves.
  GlobalAudioplayersPlatformInterface.instance = _FakeGlobalAudio();

  final messenger = tester.binding.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(
    const MethodChannel('xyz.luan/audioplayers'),
    (call) async {
      log.audio.add(call.method);
      // Some calls wait for native code to confirm them with an event.
      final event = switch (call.method) {
        'setSourceUrl' => {'event': 'audio.onPrepared', 'value': true},
        'seek' => {'event': 'audio.onSeekComplete'},
        _ => null,
      };
      if (event != null) {
        final id = (call.arguments as Map)['playerId'];
        Future.microtask(
          () => messenger.handlePlatformMessage(
            'xyz.luan/audioplayers/events/$id',
            const StandardMethodCodec().encodeSuccessEnvelope(event),
            (_) {},
          ),
        );
      }
      return null;
    },
  );
  // Any other plugin channel (audio events, global audio config) succeeds.
  messenger.allMessagesHandler = (channel, handler, message) {
    if (handler != null) return handler(message);
    if (channel.startsWith('flutter/')) return null;
    return Future.value(
      const StandardMethodCodec().encodeSuccessEnvelope(null),
    );
  };
  addTearDown(() {
    messenger.allMessagesHandler = null;
    messenger.setMockMethodCallHandler(
      const MethodChannel('xyz.luan/audioplayers'),
      null,
    );
  });

  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 2.75;
  addTearDown(tester.view.reset);

  SharedPreferences.setMockInitialValues({
    'show_help_on_launch': false,
    ...prefs,
  });
  await loadSettings();
  await tester.pumpWidget(const ScoreApp());
  await tester.pumpAndSettle();
  return log;
}

/// Loads the app's real fonts so text is measured as on a phone (the default
/// test font is much wider and would overflow the Ukrainian layout).
Future<void> loadAppFonts() async {
  const fonts = {
    'Roboto': ['assets/fonts/RobotoMono-Regular.ttf'],
    'PTSansNarrow': [
      'assets/fonts/PTSansNarrow-Regular.ttf',
      'assets/fonts/PTSansNarrow-Bold.ttf',
    ],
  };
  for (final MapEntry(key: family, value: files) in fonts.entries) {
    final loader = FontLoader(family);
    for (final file in files) {
      loader.addFont(rootBundle.load(file));
    }
    await loader.load();
  }
}

/// Reads a value back from the (in-memory) preferences store.
Future<Object?> savedPref(String key) async =>
    (await SharedPreferences.getInstance()).get(key);
