import 'package:flutter/material.dart';
import '../l10n/gen/app_localizations.dart';
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
    final l10n = AppLocalizations.of(context);
    const labelStyle = TextStyle(fontSize: 23, fontWeight: FontWeight.bold);

    // Labels shrink to fit their column so long translations (e.g. Ukrainian
    // "Попередження") never overflow.
    Widget label(String text) {
      return FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(text, style: labelStyle, maxLines: 1),
      );
    }

    Widget block(
      String text,
      int value,
      ValueChanged<int> onChanged, {
      double numberSize = 65,
    }) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          label(text),
          const SizedBox(height: 6),
          TouchNumber(
            value: value,
            onChanged: onChanged,
            textStyle: TextStyle(
              fontSize: numberSize,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      );
    }

    return Row(
      children: [
        Expanded(
          child: Column(
            children: [
              block(l10n.warning, leftWarning, onLeftWarningChanged),
              const SizedBox(height: 6),
              block(l10n.caution, leftCaution, onLeftCautionChanged),
            ],
          ),
        ),
        Expanded(
          child: block(
            l10n.double,
            doubleHits,
            onDoubleChanged,
            numberSize: 75,
          ),
        ),
        Expanded(
          child: Column(
            children: [
              block(l10n.warning, rightWarning, onRightWarningChanged),
              const SizedBox(height: 6),
              block(l10n.caution, rightCaution, onRightCautionChanged),
            ],
          ),
        ),
      ],
    );
  }
}
