import 'dart:async';
import 'package:flutter/material.dart';

/// Tap → increment
/// Short hold (~200ms) → decrement
class ScoreDisplay extends StatefulWidget {
  final int leftScore;
  final int rightScore;
  final Color color;

  final VoidCallback onLeftTap;
  final VoidCallback onLeftLongPress;
  final VoidCallback onRightTap;
  final VoidCallback onRightLongPress;

  const ScoreDisplay({
    super.key,
    required this.leftScore,
    required this.rightScore,
    required this.onLeftTap,
    required this.onLeftLongPress,
    required this.onRightTap,
    required this.onRightLongPress,
    this.color = Colors.white,
  });

  @override
  State<ScoreDisplay> createState() => _ScoreDisplayState();
}

class _ScoreDisplayState extends State<ScoreDisplay> {
  Timer? _leftHoldTimer;
  Timer? _rightHoldTimer;
  bool _leftLongTriggered = false;
  bool _rightLongTriggered = false;
  static const int _holdDelayMs = 200;

  void _onLeftDown(TapDownDetails _) {
    _leftLongTriggered = false;
    _leftHoldTimer = Timer(const Duration(milliseconds: _holdDelayMs), () {
      _leftLongTriggered = true;
      widget.onLeftLongPress();
    });
  }

  void _onLeftUp(TapUpDetails _) {
    _leftHoldTimer?.cancel();
    if (!_leftLongTriggered) widget.onLeftTap();
  }

  void _onLeftCancel() => _leftHoldTimer?.cancel();

  void _onRightDown(TapDownDetails _) {
    _rightLongTriggered = false;
    _rightHoldTimer = Timer(const Duration(milliseconds: _holdDelayMs), () {
      _rightLongTriggered = true;
      widget.onRightLongPress();
    });
  }

  void _onRightUp(TapUpDetails _) {
    _rightHoldTimer?.cancel();
    if (!_rightLongTriggered) widget.onRightTap();
  }

  void _onRightCancel() => _rightHoldTimer?.cancel();

  @override
  void dispose() {
    _leftHoldTimer?.cancel();
    _rightHoldTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontSize: 100,
      fontWeight: FontWeight.bold,
      color: widget.color,
    );

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: _onLeftDown,
          onTapUp: _onLeftUp,
          onTapCancel: _onLeftCancel,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Text("${widget.leftScore}", style: style),
          ),
        ),
        Text(":", style: style),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: _onRightDown,
          onTapUp: _onRightUp,
          onTapCancel: _onRightCancel,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Text("${widget.rightScore}", style: style),
          ),
        ),
      ],
    );
  }
}
