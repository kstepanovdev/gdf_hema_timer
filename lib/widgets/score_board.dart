import 'package:flutter/material.dart';

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
            children: [
              Text(leftName, style: const TextStyle(fontSize: 18)),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  scoreButton("-", Colors.red, onLeftMinus),
                  const SizedBox(width: 6),
                  scoreButton("+", Colors.green, onLeftPlus),
                ],
              ),
            ],
          ),
        ),

        /// Middle: score + swap fighters
        Column(
          children: [
            Text(
              "$leftScore : $rightScore",
              style: const TextStyle(
                fontSize: 42,
                fontWeight: FontWeight.bold,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.swap_horiz, size: 28, color: Colors.blueGrey),
              onPressed: swapFighters,
            ),
          ],
        ),

        /// Right fighter
        Expanded(
          child: Column(
            children: [
              Text(rightName, style: const TextStyle(fontSize: 18)),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  scoreButton("-", Colors.red, onRightMinus),
                  const SizedBox(width: 6),
                  scoreButton("+", Colors.green, onRightPlus),
                ],
              ),
            ],
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
          ),
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
