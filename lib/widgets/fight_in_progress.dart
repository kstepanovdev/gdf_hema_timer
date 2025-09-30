import 'package:flutter/material.dart';

class ActiveTimerBoard extends StatelessWidget {
  final int leftScore;
  final int rightScore;
  final Color color;

  const ActiveTimerBoard({
    super.key,
    required this.leftScore,
    required this.rightScore,
    this.color = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Text(
                "$leftScore",
                style: TextStyle(fontSize: 70, color: color),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Text(":", style: TextStyle(fontSize: 70, color: color)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Text(
                "$rightScore",
                style: TextStyle(fontSize: 70, color: color),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
