import 'package:flutter/material.dart';

class ScoreDisplay extends StatelessWidget {
  final int leftScore;
  final int rightScore;
  final Color color;

  final VoidCallback onLeftTap;
  final VoidCallback onRightTap;
  final VoidCallback? onLeftDoubleTap;
  final VoidCallback? onRightDoubleTap;

  const ScoreDisplay({
    super.key,
    required this.leftScore,
    required this.rightScore,
    required this.onLeftTap,
    required this.onRightTap,
    this.onLeftDoubleTap,
    this.onRightDoubleTap,
    this.color = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        /// Left score (tap = increment, double tap = decrement)
        GestureDetector(
          onTap: onLeftTap,
          onDoubleTap: onLeftDoubleTap,
          child: Text(
            "$leftScore",
            style: TextStyle(
              fontSize: 100,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),

        /// Separator :
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            ":",
            style: TextStyle(
              fontSize: 100,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),

        /// Right score (tap = increment, double tap = decrement)
        GestureDetector(
          onTap: onRightTap,
          onDoubleTap: onRightDoubleTap,
          child: Text(
            "$rightScore",
            style: TextStyle(
              fontSize: 100,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}
