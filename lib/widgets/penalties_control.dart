import 'package:flutter/material.dart';
import '../utils/touch_number.dart';

class PenaltiesControl extends StatelessWidget {
  final int leftWarning;
  final int rightWarning;
  final int leftCaution;
  final int rightCaution;
  final int doubleHits;

  final ValueChanged<int> onLeftWarningChanged;
  final ValueChanged<int> onRightWarningChanged;
  final ValueChanged<int> onLeftCautionChanged;
  final ValueChanged<int> onRightCautionChanged;
  final ValueChanged<int> onDoubleChanged;

  const PenaltiesControl({
    super.key,
    required this.leftWarning,
    required this.rightWarning,
    required this.leftCaution,
    required this.rightCaution,
    required this.doubleHits,
    required this.onLeftWarningChanged,
    required this.onRightWarningChanged,
    required this.onLeftCautionChanged,
    required this.onRightCautionChanged,
    required this.onDoubleChanged,
  });

  @override
  Widget build(BuildContext context) {
    const labelStyle = TextStyle(fontSize: 20, fontWeight: FontWeight.bold);

    Widget block(String label, int value, ValueChanged<int> onChanged) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: labelStyle),
          const SizedBox(height: 6),
          TouchNumber(
            value: value,
            onChanged: onChanged,
            textStyle: const TextStyle(
              fontSize: 45,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      );
    }

    Widget doubleBlock(String label, int value, ValueChanged<int> onChanged) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: labelStyle),
          const SizedBox(height: 6),
          TouchNumber(
            value: value,
            onChanged: onChanged,
            textStyle: const TextStyle(
              fontSize: 65,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        Column(
          children: [
            block("Warning", leftWarning, onLeftWarningChanged),
            const SizedBox(height: 6),
            block("Caution", leftCaution, onLeftCautionChanged),
          ],
        ),
        doubleBlock("Double", doubleHits, onDoubleChanged),
        Column(
          children: [
            block("Warning", rightWarning, onRightWarningChanged),
            const SizedBox(height: 6),
            block("Caution", rightCaution, onRightCautionChanged),
          ],
        ),
      ],
    );
  }
}
