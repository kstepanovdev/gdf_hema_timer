import 'package:flutter/material.dart';
import '../l10n/gen/app_localizations.dart';
import '../modules/settings/settings_storage.dart';
import '../theme/app_colors.dart';

/// A short controls guide shown on launch (and re-openable from Settings),
/// with a persisted "Don't show this again" checkbox.
class HelpDialog extends StatefulWidget {
  const HelpDialog({super.key});

  static Future<void> show(BuildContext context) =>
      showDialog<void>(context: context, builder: (_) => const HelpDialog());

  @override
  State<HelpDialog> createState() => _HelpDialogState();
}

class _HelpDialogState extends State<HelpDialog> {
  bool _skip = false;

  Future<void> _continue() async {
    await setShowHelpOnLaunch(!_skip);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final items = [
      (Icons.touch_app, l10n.helpTap),
      (Icons.touch_app_outlined, l10n.helpLongPress),
      (Icons.timer_outlined, l10n.helpTimer),
      (Icons.keyboard_arrow_up, l10n.helpLog),
      (Icons.restart_alt, l10n.helpResetScore),
      (Icons.menu, l10n.helpSettings),
    ];
    return AlertDialog(
      title: Text(l10n.helpTitle),
      contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // The items scroll; the checkbox below stays pinned and visible.
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final (icon, text) in items)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          spacing: 14,
                          children: [
                            Icon(icon, size: 26, color: AppColors.primary),
                            Expanded(
                              child: Text(
                                text,
                                style: const TextStyle(fontSize: 16),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
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
        ),
      ),
      actions: [
        TextButton(onPressed: _continue, child: Text(l10n.continueLabel)),
      ],
    );
  }
}
