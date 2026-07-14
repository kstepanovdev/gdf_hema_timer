import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _darkThemeKey = 'dark_theme';
const _yehorsSpecialKey = 'yehors_special';
const _localeKey = 'locale';

/// App-wide reactive settings, backed by [SharedPreferences].
///
/// These notifiers are read directly by widgets (via [ValueListenableBuilder])
/// so no external state-management package is needed. Call [loadSettings] once
/// during app startup before `runApp` to hydrate them from disk.

/// Whether the dark theme is active. Defaults to `false` (light theme).
final darkThemeEnabled = ValueNotifier<bool>(false);

/// Whether "Yehor's special" is active — plays a sound on a Double hit.
/// Defaults to `false`.
final yehorsSpecialEnabled = ValueNotifier<bool>(false);

/// Selected UI locale. `null` means "follow the system locale".
final localeOverride = ValueNotifier<Locale?>(null);

/// Hydrates the settings notifiers from persisted preferences.
Future<void> loadSettings() async {
  final prefs = await SharedPreferences.getInstance();
  darkThemeEnabled.value = prefs.getBool(_darkThemeKey) ?? false;
  yehorsSpecialEnabled.value = prefs.getBool(_yehorsSpecialKey) ?? false;
  final code = prefs.getString(_localeKey);
  localeOverride.value = (code == null || code.isEmpty) ? null : Locale(code);
}

Future<void> setDarkTheme(bool value) async {
  darkThemeEnabled.value = value;
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(_darkThemeKey, value);
}

Future<void> setYehorsSpecial(bool value) async {
  yehorsSpecialEnabled.value = value;
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(_yehorsSpecialKey, value);
}

/// Sets the UI locale. Pass `null` to follow the system locale.
Future<void> setLocale(Locale? locale) async {
  localeOverride.value = locale;
  final prefs = await SharedPreferences.getInstance();
  if (locale == null) {
    await prefs.remove(_localeKey);
  } else {
    await prefs.setString(_localeKey, locale.languageCode);
  }
}
