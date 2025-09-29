import 'package:flutter/material.dart';
import '../modules/fight_log/fight_log.dart';

/// A small bottom panel that can be tapped or dragged up to open the fight log.
///
/// Place inside a [Stack] with reserved space at the bottom.
/// Example:
/// ```dart
/// Stack(
///   children: [
///     Column(...),
///     LogHandlePanel(fightLog: fightLog),
///   ],
/// )
/// ```
class LogHandlePanel extends StatelessWidget {
  final FightLog fightLog;

  const LogHandlePanel({super.key, required this.fightLog});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 8,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          // padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 14),
          decoration: BoxDecoration(
            color: Colors.black.withAlpha(30),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.max,
            children: const [
              Icon(Icons.keyboard_arrow_up, size: 18, color: Colors.grey),
              Text(
                "Drag up for logs",
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
