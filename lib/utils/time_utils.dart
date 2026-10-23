import 'package:flutter/material.dart';
import '../l10n/gen/app_localizations.dart';
import '../modules/settings/settings_storage.dart';

String formatTime(Duration d) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(d.inMinutes.remainder(60))}:${two(d.inSeconds.remainder(60))}'
      '.${two(d.inMilliseconds.remainder(1000) ~/ 10)}';
}

/// Asks for a new round time and saves it as the default.
Future<Duration?> showTimeSelectDialog(BuildContext context) {
  var minutes = 1;
  var seconds = 30;

  return showDialog<Duration>(
    context: context,
    builder: (ctx) {
      final l10n = AppLocalizations.of(ctx);
      return StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(l10n.selectTime),
          content: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              DropdownButton<int>(
                value: minutes,
                items: [
                  for (var i = 0; i <= 10; i++)
                    DropdownMenuItem(
                      value: i,
                      child: Text(l10n.minutesLabel(i)),
                    ),
                ],
                onChanged: (v) => setState(() => minutes = v ?? minutes),
              ),
              DropdownButton<int>(
                value: seconds,
                items: [
                  for (final s in const [0, 30])
                    DropdownMenuItem(
                      value: s,
                      child: Text(l10n.secondsLabel(s)),
                    ),
                ],
                onChanged: (v) => setState(() => seconds = v ?? seconds),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l10n.cancel),
            ),
            TextButton(
              onPressed: () {
                final duration = Duration(minutes: minutes, seconds: seconds);
                saveTimerDuration(duration);
                Navigator.pop(ctx, duration);
              },
              child: Text(l10n.ok),
            ),
          ],
        ),
      );
    },
  );
}
