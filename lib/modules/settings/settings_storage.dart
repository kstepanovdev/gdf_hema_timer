import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _darkThemeKey = 'dark_theme';
const _yehorsSpecialKey = 'yehors_special';
const _localeKey = 'locale';
const _showHelpKey = 'show_help_on_launch';
const _timerKey = 'timer_duration';

/// App-wide settings backed by [SharedPreferences]. Call [loadSettings] once
/// before `runApp`; after that, reads are synchronous.
late SharedPreferences _prefs;

final darkThemeEnabled = ValueNotifier<bool>(false);

/// Plays a sound on a Double hit.
final yehorsSpecialEnabled = ValueNotifier<bool>(false);

/// Selected UI locale. `null` means "follow the system locale".
final localeOverride = ValueNotifier<Locale?>(null);

Future<void> loadSettings() async {
  _prefs = await SharedPreferences.getInstance();
  darkThemeEnabled.value = _prefs.getBool(_darkThemeKey) ?? false;
  yehorsSpecialEnabled.value = _prefs.getBool(_yehorsSpecialKey) ?? false;
  final code = _prefs.getString(_localeKey);
  localeOverride.value = (code == null || code.isEmpty) ? null : Locale(code);
}

Future<void> setDarkTheme(bool value) {
  darkThemeEnabled.value = value;
  return _prefs.setBool(_darkThemeKey, value);
}

Future<void> setYehorsSpecial(bool value) {
  yehorsSpecialEnabled.value = value;
  return _prefs.setBool(_yehorsSpecialKey, value);
}

Future<void> setLocale(Locale? locale) {
  localeOverride.value = locale;
  return locale == null
      ? _prefs.remove(_localeKey)
      : _prefs.setString(_localeKey, locale.languageCode);
}

/// Whether the controls guide is shown on launch; `true` for first-time users.
bool get showHelpOnLaunch => _prefs.getBool(_showHelpKey) ?? true;
Future<void> setShowHelpOnLaunch(bool value) =>
    _prefs.setBool(_showHelpKey, value);

Duration get savedTimerDuration =>
    Duration(seconds: _prefs.getInt(_timerKey) ?? 90);
Future<void> saveTimerDuration(Duration value) =>
    _prefs.setInt(_timerKey, value.inSeconds);
