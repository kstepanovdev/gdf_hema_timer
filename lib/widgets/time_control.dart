import 'package:flutter/material.dart';
import 'big_button.dart';

class TimeControl extends StatelessWidget {
  final VoidCallback onMinus30;
  final VoidCallback onPlus30;
  final VoidCallback onMinus1;
  final VoidCallback onPlus1;

  const TimeControl({
    super.key,
    required this.onMinus30,
    required this.onPlus30,
    required this.onMinus1,
    required this.onPlus1,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: BigButton(label: "-30s", color: Colors.blueGrey, onPressed: onMinus30)),
            const SizedBox(width: 8),
            Expanded(child: BigButton(label: "+30s", color: Colors.blueGrey, onPressed: onPlus30)),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: BigButton(label: "-1s", color: Colors.blueGrey, onPressed: onMinus1)),
            const SizedBox(width: 8),
            Expanded(child: BigButton(label: "+1s", color: Colors.blueGrey, onPressed: onPlus1)),
          ],
        ),
      ],
    );
  }
}
