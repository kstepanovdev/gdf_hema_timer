import 'package:flutter/material.dart';
import '../l10n/gen/app_localizations.dart';
import '../modules/help/help_storage.dart';
import '../theme/app_colors.dart';

/// A short controls guide shown on launch (and re-openable on demand).
///
/// Tap → increment, long-press → decrement, long-press the timer to change
/// the round time, and drag the log bar up to open the fight log.
///
/// When [showSkipOption] is true the dialog offers a "Don't show this again"
/// checkbox whose state is persisted via [setShowHelpOnLaunch].
class HelpDialog extends StatefulWidget {
  final bool showSkipOption;

  const HelpDialog({super.key, this.showSkipOption = true});

  /// Shows the guide as a modal dialog.
  static Future<void> show(
    BuildContext context, {
    bool showSkipOption = true,
  }) {
    return showDialog<void>(
      context: context,
      builder: (_) => HelpDialog(showSkipOption: showSkipOption),
    );
  }

  @override
  State<HelpDialog> createState() => _HelpDialogState();
}

class _HelpDialogState extends State<HelpDialog> {
  bool _skip = false;

  Future<void> _continue() async {
    if (widget.showSkipOption) {
      await setShowHelpOnLaunch(!_skip);
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.helpTitle),
      contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // The guide items scroll; the skip checkbox below stays pinned so
            // it is always visible even when the text is long.
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _HelpItem(icon: Icons.touch_app, text: l10n.helpTap),
                    _HelpItem(
                      icon: Icons.touch_app_outlined,
                      text: l10n.helpLongPress,
                    ),
                    _HelpItem(icon: Icons.timer_outlined, text: l10n.helpTimer),
                    _HelpItem(icon: Icons.keyboard_arrow_up, text: l10n.helpLog),
                    _HelpItem(
                      icon: Icons.restart_alt,
                      text: l10n.helpResetScore,
                    ),
                    _HelpItem(icon: Icons.menu, text: l10n.helpSettings),
                  ],
                ),
              ),
            ),
            if (widget.showSkipOption) ...[
              const Divider(height: 8),
              InkWell(
                onTap: () => setState(() => _skip = !_skip),
                child: Row(
                  children: [
                    Checkbox(
                      value: _skip,
                      onChanged: (v) => setState(() => _skip = v ?? false),
                    ),
                    Expanded(child: Text(l10n.dontShowAgain)),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _continue,
          child: Text(l10n.continueLabel),
        ),
      ],
    );
  }
}

class _HelpItem extends StatelessWidget {
  final IconData icon;
  final String text;

  const _HelpItem({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 26, color: AppColors.primary),
          const SizedBox(width: 14),
          Expanded(
            child: Text(text, style: const TextStyle(fontSize: 16)),
          ),
        ],
      ),
    );
  }
}
