import 'package:flutter/material.dart';

class TimerDisplay extends StatelessWidget {
  final String time;
  final Color color;
  final VoidCallback? onDoubleTap;
  final double fontSize;

  const TimerDisplay({
    super.key,
    required this.time,
    required this.fontSize,
    this.color = Colors.black,
    this.onDoubleTap,
  });

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontFamily: 'RobotoMono',
      fontWeight: FontWeight.bold,
      fontSize: fontSize,
      height: 0.8,
      color: color,
    );

    return GestureDetector(
      onDoubleTap: onDoubleTap,
      child: Text(time, style: style),
    );
  }
}
