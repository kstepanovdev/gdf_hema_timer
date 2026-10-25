import 'package:flutter/material.dart';
import '../l10n/gen/app_localizations.dart';
import '../theme/app_colors.dart';
import 'big_button.dart';

/// A row of buttons that nudge the timer by a few seconds.
class TimeControl extends StatelessWidget {
  static const _steps = [-1, 3, 5];

  final ValueChanged<int> onAdjust;

  const TimeControl({super.key, required this.onAdjust});

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context).secondsShort;
    return Row(
      spacing: 8,
      children: [
        for (final step in _steps)
          Expanded(
            child: BigButton(
              label: "${step > 0 ? '+' : ''}$step$s",
              color: AppColors.neutral,
              onPressed: () => onAdjust(step),
            ),
          ),
      ],
    );
  }
}
