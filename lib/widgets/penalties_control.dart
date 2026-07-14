import 'dart:math' as math;

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
    // Carry the inherited font family explicitly so the width measurement in
    // [_fitFontSize] uses the same font the labels actually render with
    // (RobotoMono in English, the condensed PT Sans Narrow in Ukrainian).
    final labelStyle = TextStyle(
      fontSize: 21,
      fontWeight: FontWeight.bold,
      fontFamily: Theme.of(context).textTheme.bodyMedium?.fontFamily,
    );
    final textScaler = MediaQuery.textScalerOf(context);

    Widget block(
      Widget labelWidget,
      int value,
      ValueChanged<int> onChanged, {
      double numberSize = 65,
    }) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          labelWidget,
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

    // "Double" keeps its own independent fit.
    Widget doubleLabel(String text) {
      return FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(text, style: labelStyle, maxLines: 1),
      );
    }

    // The penalty columns hold long labels (e.g. Ukrainian "Попередження"), so
    // they get more width than the double-hit column, which only shows a number
    // and a short label and scales down to fit whatever it's given.
    const sideFlex = 5;
    const doubleFlex = 3;

    return LayoutBuilder(
      builder: (context, constraints) {
        final sideColumnWidth =
            constraints.maxWidth * sideFlex / (sideFlex * 2 + doubleFlex);

        // Warning and caution translations differ in length (e.g. Ukrainian
        // "Зауваження" vs "Попередження"), so scaling each independently would
        // render them at different sizes. Pick one font size that fits the
        // longest of the two — the smallest scale — and use it for both.
        final penaltyLabelSize = _fitFontSize(
          [l10n.warning, l10n.caution],
          labelStyle,
          // Leave a little slack so a label sized right at the column edge
          // isn't clipped by sub-pixel rounding.
          sideColumnWidth * 0.95,
          textScaler,
        );
        final penaltyLabelStyle = labelStyle.copyWith(fontSize: penaltyLabelSize);

        Widget penaltyLabel(String text) =>
            Text(text, style: penaltyLabelStyle, maxLines: 1);

        return Row(
          children: [
            Expanded(
              flex: sideFlex,
              child: Column(
                children: [
                  block(penaltyLabel(l10n.warning), leftWarning,
                      onLeftWarningChanged),
                  const SizedBox(height: 6),
                  block(penaltyLabel(l10n.caution), leftCaution,
                      onLeftCautionChanged),
                ],
              ),
            ),
            Expanded(
              flex: doubleFlex,
              child: block(
                doubleLabel(l10n.double),
                doubleHits,
                onDoubleChanged,
                numberSize: 75,
              ),
            ),
            Expanded(
              flex: sideFlex,
              child: Column(
                children: [
                  block(penaltyLabel(l10n.warning), rightWarning,
                      onRightWarningChanged),
                  const SizedBox(height: 6),
                  block(penaltyLabel(l10n.caution), rightCaution,
                      onRightCautionChanged),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  /// Largest font size (<= [style]'s size) at which every one of [texts] fits
  /// within [maxWidth] on a single line, i.e. the smallest per-text fit.
  static double _fitFontSize(
    List<String> texts,
    TextStyle style,
    double maxWidth,
    TextScaler textScaler,
  ) {
    final baseSize = style.fontSize!;
    var size = baseSize;
    for (final text in texts) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: style),
        maxLines: 1,
        textDirection: TextDirection.ltr,
        textScaler: textScaler,
      )..layout();
      if (painter.width > maxWidth) {
        size = math.min(size, baseSize * maxWidth / painter.width);
      }
    }
    return size;
  }
}
