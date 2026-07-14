import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'pages/score_page.dart';
import 'modules/settings/settings_storage.dart';
import 'theme/app_theme.dart';
import 'l10n/gen/app_localizations.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await loadSettings();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  runApp(const ScoreApp());
}

class ScoreApp extends StatelessWidget {
  const ScoreApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([darkThemeEnabled, localeOverride]),
      builder: (context, _) {
        return MaterialApp(
          onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: darkThemeEnabled.value ? ThemeMode.dark : ThemeMode.light,
          locale: localeOverride.value,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          // `locale: null` follows the system locale; resolve it against what
          // we ship and fall back to English when the system language isn't
          // one of them.
          localeResolutionCallback: (locale, supported) {
            for (final s in supported) {
              if (s.languageCode == locale?.languageCode) return s;
            }
            return const Locale('en');
          },
          // Swap to the condensed font for the Ukrainian UI only. Runs below
          // Localizations, so the resolved locale is available here.
          builder: (context, child) {
            if (child == null) return const SizedBox.shrink();
            final isUk = Localizations.localeOf(context).languageCode == 'uk';
            return isUk
                ? Theme(data: AppTheme.withUkFont(Theme.of(context)), child: child)
                : child;
          },
          home: const ScorePage(),
        );
      },
    );
  }
}
