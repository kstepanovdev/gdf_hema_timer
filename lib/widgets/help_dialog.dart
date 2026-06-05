import 'package:flutter/material.dart';
import '../modules/help/help_storage.dart';

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
    return AlertDialog(
      title: const Text("How to use"),
      contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _HelpItem(
              icon: Icons.touch_app,
              text: "Tap a number to add a point.",
            ),
            const _HelpItem(
              icon: Icons.touch_app_outlined,
              text: "Long-press a number to remove a point.",
            ),
            const _HelpItem(
              icon: Icons.timer_outlined,
              text: "Long-press the timer to change the round time.",
            ),
            const _HelpItem(
              icon: Icons.keyboard_arrow_up,
              text: "Drag the log bar up to open the fight log.",
            ),
            if (widget.showSkipOption) ...[
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 0),
                child: InkWell(
                  onTap: () => setState(() => _skip = !_skip),
                  child: Row(
                    children: [
                      Checkbox(
                        value: _skip,
                        onChanged: (v) => setState(() => _skip = v ?? false),
                      ),
                      const Expanded(
                        child: Text("Don't show this again"),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _continue,
          child: const Text("Continue"),
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
          Icon(icon, size: 26, color: Colors.deepPurple),
          const SizedBox(width: 14),
          Expanded(
            child: Text(text, style: const TextStyle(fontSize: 16)),
          ),
        ],
      ),
    );
  }
}
