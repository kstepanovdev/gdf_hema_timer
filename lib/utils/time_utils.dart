import 'package:flutter/material.dart';
import 'package:hema_scoring_machine/modules/timer/storage.dart';

String formatTime(Duration d) {
  final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  final millis = d.inMilliseconds.remainder(1000).toString().padLeft(3, '0');
  return "$minutes:$seconds.$millis";
}

Future<Duration?> showTimeSelectDialog(BuildContext context) async {
  int minutes = 1;
  int seconds = 30;

  return showDialog<Duration>(
    context: context,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Select Time'),
            content: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Minutes dropdown
                DropdownButton<int>(
                  value: minutes,
                  items: List.generate(
                    11,
                    (i) => DropdownMenuItem(value: i, child: Text('$i m')),
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
                      child: Text("$value s"),
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
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  final newTimer = Duration(minutes: minutes, seconds: seconds);
                  saveTimerValue(newTimer);
                  Navigator.pop(ctx, newTimer);
                },
                child: const Text('OK'),
              ),
            ],
          );
        },
      );
    },
  );
}
