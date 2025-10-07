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
    required this.onLeftCautionPlus,
    required this.onLeftCautionMinus,
    required this.onRightCautionPlus,
    required this.onRightCautionMinus,
    required this.onDoublePlus,
    required this.onDoubleMinus,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Left column (Warnings & Cautions)
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _counterBlock(
                  "Warning",
                  leftWarning,
                  onLeftWarningMinus,
                  onLeftWarningPlus,
                ),
                const SizedBox(height: 12),
                _counterBlock(
                  "Caution",
                  leftCaution,
                  onLeftCautionMinus,
                  onLeftCautionPlus,
                ),
              ],
            ),
          ),

          // Middle column — Double (vertical layout, big buttons)
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  "Double",
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                _bigButton("$doubleHits", Colors.green, onDoublePlus),
                const SizedBox(height: 8),
                _bigButton("$doubleHits", Colors.red, onDoubleMinus),
              ],
            ),
          ),

          // Right column (Warnings & Cautions)
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _counterBlock(
                  "Warning",
                  rightWarning,
                  onRightWarningMinus,
                  onRightWarningPlus,
                ),
                const SizedBox(height: 12),
                _counterBlock(
                  "Caution",
                  rightCaution,
                  onRightCautionMinus,
                  onRightCautionPlus,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _counterBlock(
    String label,
    int counter,
    VoidCallback onMinus,
    VoidCallback onPlus,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          "$label: $counter",
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
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
          style: const TextStyle(
            fontSize: 20,
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _bigButton(String label, Color color, VoidCallback onPressed) {
    return SizedBox(
      width: 64,
      height: 64,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        onPressed: onPressed,
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 28,
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
