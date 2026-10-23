import 'package:flutter/material.dart';
import '../l10n/gen/app_localizations.dart';
import '../theme/app_colors.dart';

/// A bottom bar that calls [onOpen] when dragged up.
class LogHandlePanel extends StatelessWidget {
  final VoidCallback onOpen;

  const LogHandlePanel({super.key, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    // The faint overlay all but vanishes on a dark background, so lift the
    // alpha in dark theme to keep the handle visible.
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onVerticalDragUpdate: (details) {
        if ((details.primaryDelta ?? 0) < -10) onOpen();
      },
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: Theme.of(
            context,
          ).colorScheme.onSurface.withAlpha(isDark ? 45 : 20),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.keyboard_arrow_up,
              size: 30,
              color: AppColors.hint,
            ),
            Text(
              AppLocalizations.of(context).dragUpForLogs,
              style: const TextStyle(color: AppColors.hint, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}
