import 'package:flutter/material.dart';
import 'package:hema_scoring_machine/widgets/score_display.dart';

class ScoreBoard extends StatelessWidget {
  final String leftName;
  final String rightName;
  final int leftScore;
  final int rightScore;

  final VoidCallback onLeftPlus;
  final VoidCallback onLeftMinus;
  final VoidCallback onRightPlus;
  final VoidCallback onRightMinus;
  final VoidCallback swapFighters;

  const ScoreBoard({
    super.key,
    required this.leftName,
    required this.rightName,
    required this.leftScore,
    required this.rightScore,
    required this.onLeftPlus,
    required this.onLeftMinus,
    required this.onRightPlus,
    required this.onRightMinus,
    required this.swapFighters,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        /// Left fighter
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [Text(leftName, style: const TextStyle(fontSize: 18))],
          ),
        ),

        /// Middle: score + swap fighters
        Column(
          children: [
            ScoreDisplay(
              leftScore: leftScore,
              rightScore: rightScore,
              color: Colors.black,
              onLeftTap: onLeftPlus,
              onLeftDoubleTap: onLeftMinus,
              onRightTap: onRightPlus,
              onRightDoubleTap: onRightMinus,
            ),
            IconButton(
              icon: const Icon(
                Icons.swap_horiz,
                size: 28,
                color: Colors.blueGrey,
              ),
              onPressed: swapFighters,
            ),
          ],
        ),

        /// Right fighter
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [Text(rightName, style: const TextStyle(fontSize: 18))],
          ),
        ),
      ],
    );
  }

  Widget scoreButton(String label, Color color, VoidCallback onPressed) {
    return SizedBox(
      width: 55,
      height: 45,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
        onPressed: onPressed,
        child: Text(
          label,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
