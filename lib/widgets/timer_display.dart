import 'package:flutter/material.dart';

class TimerDisplay extends StatelessWidget {
  final String time;
  final Color color;
  final VoidCallback? onLongPress;
  final double fontSize;

  const TimerDisplay({
    super.key,
    required this.time,
    required this.fontSize,
    this.color = Colors.black,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontFamily: 'Roboto',
      fontWeight: FontWeight.bold,
      fontSize: fontSize,
      height: 0.8,
      color: color,
    );

    return GestureDetector(
      onLongPress: onLongPress,
      child: Text(time, style: style),
    );
  }
}
