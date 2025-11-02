import 'dart:async';
import 'package:flutter/material.dart';

/// Controlled number widget
/// Tap → increment
/// Long press (~200ms) → decrement
class TouchNumber extends StatefulWidget {
  final int value;
  final ValueChanged<int> onChanged;
  final TextStyle textStyle;

  const TouchNumber({
    super.key,
    required this.value,
    required this.onChanged,
    required this.textStyle,
  });

  @override
  State<TouchNumber> createState() => _TouchNumberState();
}

class _TouchNumberState extends State<TouchNumber> {
  Timer? _holdTimer;
  bool _longTriggered = false;
  static const _holdDelay = Duration(milliseconds: 200);

  void _onTapDown(TapDownDetails _) {
    _longTriggered = false;
    _holdTimer = Timer(_holdDelay, () {
      _longTriggered = true;
      if (widget.value > 0) widget.onChanged(widget.value - 1);
    });
  }

  void _onTapUp(TapUpDetails _) {
    _holdTimer?.cancel();
    if (!_longTriggered) widget.onChanged(widget.value + 1);
  }

  void _onTapCancel() => _holdTimer?.cancel();

  @override
  void dispose() {
    _holdTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      behavior: HitTestBehavior.translucent,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          "${widget.value}",
          style: widget.textStyle.copyWith(height: 1),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
