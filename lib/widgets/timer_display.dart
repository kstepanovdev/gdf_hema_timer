import 'package:flutter/material.dart';

class TimerDisplay extends StatelessWidget {
  final String time;

  /// Text color. When null, follows the theme (`onSurface`) so the timer stays
  /// legible in both light and dark themes.
  final Color? color;
  final VoidCallback? onLongPress;
  final double fontSize;

  const TimerDisplay({
    super.key,
    required this.time,
    required this.fontSize,
    this.color,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontFamily: 'Roboto',
      fontWeight: FontWeight.bold,
      fontSize: fontSize,
      height: 0.8,
      color: color ?? Theme.of(context).colorScheme.onSurface,
    );

    return GestureDetector(
      onLongPress: onLongPress,
      child: Text(time, style: style),
    );
  }
}
