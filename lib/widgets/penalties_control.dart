import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../l10n/gen/app_localizations.dart';
import '../modules/fight_log/fight_event.dart';
import '../utils/touch_number.dart';

class PenaltiesControl extends StatelessWidget {
  final int Function(Fighter, PenaltyKind) penalty;
  final void Function(Fighter, PenaltyKind, int) onPenaltyChanged;
  final int doubleHits;
  final ValueChanged<int> onDoubleChanged;

  const PenaltiesControl({
    super.key,
    required this.penalty,
    required this.onPenaltyChanged,
    required this.doubleHits,
    required this.onDoubleChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    String label(PenaltyKind kind) => switch (kind) {
      PenaltyKind.warning => l10n.warning,
      PenaltyKind.caution => l10n.caution,
    };
    // Carry the inherited font family explicitly so the width measurement in
    // [_fitFontSize] uses the font the labels actually render with.
    final labelStyle = TextStyle(
      fontSize: 21,
      fontWeight: FontWeight.bold,
      fontFamily: Theme.of(context).textTheme.bodyMedium?.fontFamily,
    );
    final textScaler = MediaQuery.textScalerOf(context);

    Widget block(
      Widget label,
      int value,
      ValueChanged<int> onChanged, {
      double numberSize = 65,
    }) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        spacing: 6,
        children: [
          label,
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

    // Penalty columns hold long labels (e.g. Ukrainian "Попередження"), so
    // they get more width than the double-hit column.
    const sideFlex = 5;
    const doubleFlex = 3;

    return LayoutBuilder(
      builder: (context, constraints) {
        // One font size for both penalty labels, so translations of different
        // lengths don't render at different sizes. The 0.95 leaves slack for
        // sub-pixel rounding at the column edge.
        final penaltyLabelStyle = labelStyle.copyWith(
          fontSize: _fitFontSize(
            PenaltyKind.values.map(label),
            labelStyle,
            constraints.maxWidth *
                sideFlex /
                (sideFlex * 2 + doubleFlex) *
                0.95,
            textScaler,
          ),
        );

        Widget side(Fighter fighter) => Expanded(
          flex: sideFlex,
          child: Column(
            spacing: 6,
            children: [
              for (final kind in PenaltyKind.values)
                block(
                  Text(label(kind), style: penaltyLabelStyle, maxLines: 1),
                  penalty(fighter, kind),
                  (v) => onPenaltyChanged(fighter, kind, v),
                ),
            ],
          ),
        );

        return Row(
          children: [
            side(Fighter.left),
            Expanded(
              flex: doubleFlex,
              child: block(
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(l10n.double, style: labelStyle, maxLines: 1),
                ),
                doubleHits,
                onDoubleChanged,
                numberSize: 75,
              ),
            ),
            side(Fighter.right),
          ],
        );
      },
    );
  }

  /// Largest font size (<= [style]'s size) at which every one of [texts] fits
  /// within [maxWidth] on a single line.
  static double _fitFontSize(
    Iterable<String> texts,
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
      painter.dispose();
    }
    return size;
  }
}
