import 'package:flutter/material.dart';

class ScoreControls extends StatelessWidget {
  final VoidCallback onLeftPlus;
  final VoidCallback onLeftMinus;
  final VoidCallback onRightPlus;
  final VoidCallback onRightMinus;

  const ScoreControls({
    super.key,
    required this.onLeftPlus,
    required this.onLeftMinus,
    required this.onRightPlus,
    required this.onRightMinus,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              scoreButton("-", Colors.red, onLeftMinus),
              scoreButton("+", Colors.green, onLeftPlus),
            ],
          ),
        ),
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              scoreButton("-", Colors.red, onRightMinus),
              scoreButton("+", Colors.green, onRightPlus),
            ],
          ),
        ),
      ],
    );
  }

  Widget scoreButton(String label, Color color, VoidCallback onPressed) {
    return SizedBox(
      width: 80,
      height: 60,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
        onPressed: onPressed,
        child: Text(
          label,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
