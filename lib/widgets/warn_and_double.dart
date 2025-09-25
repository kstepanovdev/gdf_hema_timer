import 'package:flutter/material.dart';

class WarnAndDouble extends StatelessWidget {
  final int leftWarn;
  final int rightWarn;
  final int doubleHits;

  final VoidCallback onLeftWarnPlus;
  final VoidCallback onLeftWarnMinus;
  final VoidCallback onRightWarnPlus;
  final VoidCallback onRightWarnMinus;
  final VoidCallback onDoublePlus;
  final VoidCallback onDoubleMinus;

  const WarnAndDouble({
    super.key,
    required this.leftWarn,
    required this.rightWarn,
    required this.doubleHits,
    required this.onLeftWarnPlus,
    required this.onLeftWarnMinus,
    required this.onRightWarnPlus,
    required this.onRightWarnMinus,
    required this.onDoublePlus,
    required this.onDoubleMinus,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        /// First row: warnings (left + right)
        Row(
          children: [
            Expanded(
              child: _counterBlock("Warn: $leftWarn", onLeftWarnMinus, onLeftWarnPlus),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _counterBlock("Warn: $rightWarn", onRightWarnMinus, onRightWarnPlus),
            ),
          ],
        ),

        const SizedBox(height: 12),

        /// Second row: double hits (centered)
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _counterBlock("Double: $doubleHits", onDoubleMinus, onDoublePlus),
          ],
        ),
      ],
    );
  }

  Widget _counterBlock(String label, VoidCallback onMinus, VoidCallback onPlus) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 16)),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
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
      width: 60,
      height: 45,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
        onPressed: onPressed,
        child: Text(label, style: const TextStyle(fontSize: 18)),
      ),
    );
  }
}
