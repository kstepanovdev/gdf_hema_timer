import 'package:flutter/material.dart';

class BigButton extends StatelessWidget {
  final String label;
  final Color color;
  final double fontSize;
  final VoidCallback onPressed;

  const BigButton({
    super.key,
    required this.label,
    required this.color,
    this.fontSize = 20,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        onPressed: onPressed,
        child: Text(label, style: TextStyle(fontSize: fontSize)),
      ),
    );
  }
}
