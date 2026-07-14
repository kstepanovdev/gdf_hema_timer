import 'package:flutter/material.dart';
import '../l10n/gen/app_localizations.dart';
import '../modules/fight_log/fight_log.dart';
import '../theme/app_colors.dart';

/// A small bottom panel that can be tapped or dragged up to open the fight log.
///
/// Place inside a [Stack] with reserved space at the bottom.
/// Example:
/// ```dart
/// Stack(
///   children: [
///     Column(...),
///     LogHandlePanel(fightLog: fightLog),
///   ],
/// )
/// ```
class LogHandlePanel extends StatelessWidget {
  final FightLog fightLog;

  const LogHandlePanel({super.key, required this.fightLog});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      // padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.onSurface.withAlpha(20),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(Icons.keyboard_arrow_up, size: 30, color: AppColors.hint),
          Text(
            AppLocalizations.of(context).dragUpForLogs,
            style: const TextStyle(color: AppColors.hint, fontSize: 14),
          ),
        ],
      ),
    );
  }
}
