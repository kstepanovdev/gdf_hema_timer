import 'package:shared_preferences/shared_preferences.dart';

Future<void> saveTimerValue(Duration duration) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setInt('timer_duration', duration.inSeconds);
}

Future<Duration> loadTimerValue() async {
  final prefs = await SharedPreferences.getInstance();
  final seconds = prefs.getInt('timer_duration') ?? 90;
  return Duration(seconds: seconds);
}
