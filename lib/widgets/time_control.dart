import 'package:flutter/material.dart';
import '../l10n/gen/app_localizations.dart';
import '../theme/app_colors.dart';
import 'big_button.dart';

class TimeControl extends StatelessWidget {
  final VoidCallback onMinus1;
  final VoidCallback onPlus3;
  final VoidCallback onPlus5;

  const TimeControl({
    super.key,
    required this.onMinus1,
    required this.onPlus3,
    required this.onPlus5,
  });

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context).secondsShort;
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: BigButton(
                label: "-1$s",
                color: AppColors.neutral,
                onPressed: onMinus1,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: BigButton(
                label: "+3$s",
                color: AppColors.neutral,
                onPressed: onPlus3,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: BigButton(
                label: "+5$s",
                color: AppColors.neutral,
                onPressed: onPlus5,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
