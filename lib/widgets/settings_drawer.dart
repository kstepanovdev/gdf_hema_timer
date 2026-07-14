import 'package:flutter/material.dart';
import '../l10n/gen/app_localizations.dart';
import '../modules/settings/settings_storage.dart';
import 'help_dialog.dart';

/// The left slide-in settings panel, opened by dragging from the left screen
/// edge. Holds the app-wide toggles ([darkThemeEnabled], [yehorsSpecialEnabled],
/// [localeOverride]) and a shortcut to re-show the tutorial ([HelpDialog]).
class SettingsDrawer extends StatelessWidget {
  const SettingsDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Drawer(
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              margin: EdgeInsets.zero,
              child: Align(
                alignment: Alignment.bottomLeft,
                child: Text(
                  l10n.settingsTitle,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            ValueListenableBuilder<bool>(
              valueListenable: darkThemeEnabled,
              builder: (context, isDark, _) {
                return SwitchListTile(
                  secondary: const Icon(Icons.dark_mode),
                  title: Text(l10n.darkTheme),
                  value: isDark,
                  onChanged: (v) => setDarkTheme(v),
                );
              },
            ),
            ValueListenableBuilder<bool>(
              valueListenable: yehorsSpecialEnabled,
              builder: (context, enabled, _) {
                return SwitchListTile(
                  secondary: const Icon(Icons.volume_up),
                  title: Text(l10n.yehorsSpecial),
                  subtitle: Text(l10n.yehorsSpecialSubtitle),
                  value: enabled,
                  onChanged: (v) => setYehorsSpecial(v),
                );
              },
            ),
            const Divider(),
            ValueListenableBuilder<Locale?>(
              valueListenable: localeOverride,
              builder: (context, locale, _) {
                // `null` = follow the system locale (falls back to English when
                // the system language isn't one we ship). A stored override
                // pins one of the languages we actually offer.
                return ListTile(
                  leading: const Icon(Icons.language),
                  title: Text(l10n.language),
                  trailing: DropdownButton<String?>(
                    value: locale?.languageCode,
                    underline: const SizedBox.shrink(),
                    onChanged: (code) =>
                        setLocale(code == null ? null : Locale(code)),
                    items: [
                      DropdownMenuItem(
                        value: null,
                        child: Text(l10n.systemDefault),
                      ),
                      const DropdownMenuItem(
                        value: 'en',
                        child: Text('English'),
                      ),
                      const DropdownMenuItem(
                        value: 'uk',
                        child: Text('Українська'),
                      ),
                    ],
                  ),
                );
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.help_outline),
              title: Text(l10n.showTutorial),
              onTap: () {
                Navigator.of(context).pop();
                HelpDialog.show(context, showSkipOption: true);
              },
            ),
          ],
        ),
      ),
    );
  }
}
