import 'package:flutter/material.dart';
import '../utils/touch_number.dart';

class ScoreBoard extends StatelessWidget {
  final int leftScore;
  final int rightScore;
  final ValueChanged<int> onLeftChanged;
  final ValueChanged<int> onRightChanged;

  const ScoreBoard({
    super.key,
    required this.leftScore,
    required this.rightScore,
    required this.onLeftChanged,
    required this.onRightChanged,
  });

  @override
  Widget build(BuildContext context) {
    final textStyle = TextStyle(
      fontSize: 100,
      fontWeight: FontWeight.bold,
      color: Theme.of(context).colorScheme.onSurface,
      height: 1,
    );

    Widget number(int value, ValueChanged<int> onChanged, Alignment align) =>
        Expanded(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: align,
            child: TouchNumber(
              value: value,
              onChanged: onChanged,
              textStyle: textStyle,
            ),
          ),
        );

    return Row(
      children: [
        number(leftScore, onLeftChanged, Alignment.centerRight),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15),
          child: Text(":", style: textStyle),
        ),
        number(rightScore, onRightChanged, Alignment.centerLeft),
      ],
    );
  }
}
