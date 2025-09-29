import 'package:flutter/material.dart';
import 'score_display.dart';

class ScoreBoard extends StatelessWidget {
  final String leftName;
  final String rightName;
  final int leftScore;
  final int rightScore;
  final Color color;

  final VoidCallback onLeftTap;
  final VoidCallback onLeftLongPress;
  final VoidCallback onRightTap;
  final VoidCallback onRightLongPress;
  final VoidCallback swapFighters;

  const ScoreBoard({
    super.key,
    required this.leftName,
    required this.rightName,
    required this.leftScore,
    required this.rightScore,
    this.color = Colors.black,

    required this.onLeftTap,
    required this.onLeftLongPress,
    required this.onRightTap,
    required this.onRightLongPress,
    required this.swapFighters,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(leftName, style: TextStyle(fontSize: 18, color: color)),
            IconButton(
              icon: Icon(Icons.swap_horiz, size: 28, color: color),
              onPressed: swapFighters,
            ),
            Text(rightName, style: TextStyle(fontSize: 18, color: color)),
          ],
        ),
        ScoreDisplay(
          leftScore: leftScore,
          rightScore: rightScore,
          onLeftTap: onLeftTap,
          onLeftLongPress: onLeftLongPress,
          onRightTap: onRightTap,
          onRightLongPress: onRightLongPress,
          color: color,
        ),
      ],
    );
  }
}
