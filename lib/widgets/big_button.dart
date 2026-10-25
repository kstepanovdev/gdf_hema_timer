import 'package:flutter/material.dart';

class BigButton extends StatelessWidget {
  final String label;
  final Color color;
  final double fontSize;
  final double? width;
  final VoidCallback onPressed;
  final VoidCallback? onLongPress;

  const BigButton({
    super.key,
    required this.label,
    required this.color,
    this.fontSize = 20,
    this.width,
    required this.onPressed,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        onPressed: onPressed,
        onLongPress: onLongPress,
        child: Text(label, style: TextStyle(fontSize: fontSize)),
      ),
    );
  }
}
