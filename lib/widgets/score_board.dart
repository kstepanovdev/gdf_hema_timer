import 'package:flutter/material.dart';
import '../utils/touch_number.dart';

class ScoreBoard extends StatelessWidget {
  final String leftName;
  final String rightName;
  final int leftScore;
  final int rightScore;
  final Color color;

  final ValueChanged<int> onLeftChanged;
  final ValueChanged<int> onRightChanged;
  final VoidCallback swapFighters;

  const ScoreBoard({
    super.key,
    required this.leftName,
    required this.rightName,
    required this.leftScore,
    required this.rightScore,
    required this.onLeftChanged,
    required this.onRightChanged,
    required this.swapFighters,
    this.color = Colors.black,
  });

  @override
  Widget build(BuildContext context) {
    final textStyle = TextStyle(
      fontSize: 100,
      fontWeight: FontWeight.bold,
      color: color,
      height: 1,
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: TouchNumber(
                  value: leftScore,
                  onChanged: onLeftChanged,
                  textStyle: textStyle,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15),
              child: Text(":", style: textStyle),
            ),
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: TouchNumber(
                  value: rightScore,
                  onChanged: onRightChanged,
                  textStyle: textStyle,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
