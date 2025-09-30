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
    return GestureDetector(
      onDoubleTap: onDoubleTap,
      child: Padding(
        padding: const EdgeInsets.only(top: 16),
        child: Text(
          time,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.bold,
            fontFamily: 'RobotoMono',
            color: color,
          ),
        ),
      ),
    );
  }
}
