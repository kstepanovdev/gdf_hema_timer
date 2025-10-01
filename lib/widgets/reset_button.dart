import 'package:flutter/material.dart';

class ResetButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onPressed;
  final VoidCallback onLongPress;

  const ResetButton({
    super.key,
    required this.label,
    required this.color,
    required this.onPressed,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        onPressed: onPressed,
        onLongPress: onLongPress,
        child: Text(label, style: TextStyle(fontSize: 35)),
      ),
    );
  }
}
