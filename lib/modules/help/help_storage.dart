import 'package:shared_preferences/shared_preferences.dart';

const _showHelpKey = 'show_help_on_launch';

/// Whether the controls guide should be shown automatically on launch.
/// Defaults to `true` so first-time users always see it.
Future<bool> loadShowHelpOnLaunch() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(_showHelpKey) ?? true;
}

Future<void> setShowHelpOnLaunch(bool value) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(_showHelpKey, value);
}
