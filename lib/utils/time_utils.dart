import 'package:flutter/material.dart';
import 'package:gdf_hema_timer/l10n/gen/app_localizations.dart';
import 'package:gdf_hema_timer/modules/timer/storage.dart';

String formatTime(Duration d) {
  final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  final centis = (d.inMilliseconds.remainder(1000) ~/ 10).toString().padLeft(2, '0');
  return "$minutes:$seconds.$centis";
}

Future<Duration?> showTimeSelectDialog(BuildContext context) async {
  int minutes = 1;
  int seconds = 30;

  return showDialog<Duration>(
    context: context,
    builder: (ctx) {
      final l10n = AppLocalizations.of(ctx);
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text(l10n.selectTime),
            content: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Minutes dropdown
                DropdownButton<int>(
                  value: minutes,
                  items: List.generate(
                    11,
                    (i) => DropdownMenuItem(
                      value: i,
                      child: Text(l10n.minutesLabel(i)),
                    ),
                  ),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        minutes = val;
                      });
                    }
                  },
                ),

                // Seconds dropdown
                DropdownButton<int>(
                  value: seconds,
                  items: List.generate(2, (i) {
                    final value = i * 30;
                    return DropdownMenuItem(
                      value: value,
                      child: Text(l10n.secondsLabel(value)),
                    );
                  }),

                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        seconds = val;
                      });
                    }
                  },
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
                  final newTimer = Duration(minutes: minutes, seconds: seconds);
                  saveTimerValue(newTimer);
                  Navigator.pop(ctx, newTimer);
                },
                child: Text(l10n.ok),
              ),
            ],
          );
        },
      );
    },
  );
}
