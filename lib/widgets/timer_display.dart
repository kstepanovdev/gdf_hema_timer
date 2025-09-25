import 'package:flutter/material.dart';

class TimerDisplay extends StatelessWidget {
  final String time;
  final Color color;

  const TimerDisplay({super.key, required this.time, this.color = Colors.black});

  @override
  Widget build(BuildContext context) {
    return Text(
      time,
      style: TextStyle(
        fontSize: 36,
        fontWeight: FontWeight.bold,
        fontFamily: 'RobotoMono',
        color: color,
      ),
    );
  }
}
