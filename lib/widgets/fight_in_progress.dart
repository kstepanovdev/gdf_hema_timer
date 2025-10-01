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
    final style = TextStyle(
      fontFamily: 'RobotoMono',
      fontWeight: FontWeight.bold,
      fontSize: 90,
      height: 0.8,
      letterSpacing: 2,
      color: Colors.white,
    );
    const padding = EdgeInsets.symmetric(horizontal: 8.0);

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Padding(
              padding: padding,
              child: Text("$leftScore", style: style),
            ),
            Padding(
              padding: padding,
              child: Text(":", style: style),
            ),
            Padding(
              padding: padding,
              child: Text("$rightScore", style: style),
            ),
          ],
        ),
      ],
    );
  }
}
