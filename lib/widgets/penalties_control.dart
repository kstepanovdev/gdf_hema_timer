import 'package:flutter/material.dart';

class PenaltiesControl extends StatelessWidget {
  final int leftWarning;
  final int rightWarning;
  final int leftCaution;
  final int rightCaution;
  final int doubleHits;

  final VoidCallback onLeftWarningPlus;
  final VoidCallback onLeftWarningMinus;
  final VoidCallback onRightWarningPlus;
  final VoidCallback onRightWarningMinus;
  final VoidCallback onLeftCautionPlus;
  final VoidCallback onLeftCautionMinus;
  final VoidCallback onRightCautionPlus;
  final VoidCallback onRightCautionMinus;

  final VoidCallback onDoublePlus;
  final VoidCallback onDoubleMinus;

  const PenaltiesControl({
    super.key,
    required this.leftWarning,
    required this.rightWarning,
    required this.leftCaution,
    required this.rightCaution,
    required this.doubleHits,
    required this.onLeftWarningPlus,
    required this.onLeftWarningMinus,
    required this.onRightWarningPlus,
    required this.onRightWarningMinus,
    required this.onLeftCautionMinus,
    required this.onLeftCautionPlus,
    required this.onRightCautionMinus,
    required this.onRightCautionPlus,
    required this.onDoublePlus,
    required this.onDoubleMinus,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: _counterBlock(
                "Warning: $leftWarning",
                onLeftWarningMinus,
                onLeftWarningPlus,
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: _counterBlock(
                "Double: $doubleHits",
                onDoubleMinus,
                onDoublePlus,
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: _counterBlock(
                "Warning: $rightWarning",
                onRightWarningMinus,
                onRightWarningPlus,
              ),
            ),
          ],
        ),
        Row(
          // mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: _counterBlock(
                "Caution: $leftCaution",
                onLeftCautionMinus,
                onLeftCautionPlus,
              ),
            ),
            Expanded(
              child: _counterBlock(
                "Caution: $rightCaution",
                onRightCautionMinus,
                onRightCautionPlus,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _counterBlock(
    String label,
    VoidCallback onMinus,
    VoidCallback onPlus,
  ) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 18)),
        const SizedBox(height: 4),
        Row(
          children: [
            _smallButton("-", Colors.red, onMinus),
            const SizedBox(width: 6),
            _smallButton("+", Colors.green, onPlus),
          ],
        ),
      ],
    );
  }

  Widget _smallButton(String label, Color color, VoidCallback onPressed) {
    return SizedBox(
      width: 45,
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
          style: const TextStyle(fontSize: 18, color: Colors.white),
        ),
      ),
    );
  }
}
