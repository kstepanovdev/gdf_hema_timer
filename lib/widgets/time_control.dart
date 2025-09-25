import 'package:flutter/material.dart';
import 'big_button.dart';

class TimeControl extends StatelessWidget {
  final VoidCallback onMinus1;
  final VoidCallback onPlus3;
  final VoidCallback onPlus5;

  const TimeControl({
    super.key,
    required this.onMinus1,
    required this.onPlus3,
    required this.onPlus5,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: BigButton(
                label: "-1s",
                color: Colors.blueGrey,
                onPressed: onMinus1,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: BigButton(
                label: "+3s",
                color: Colors.blueGrey,
                onPressed: onPlus3,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: BigButton(
                label: "+5s",
                color: Colors.blueGrey,
                onPressed: onPlus5,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
