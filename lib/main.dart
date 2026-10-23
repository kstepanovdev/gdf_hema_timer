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
      builder: (context, _) => MaterialApp(
        onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: darkThemeEnabled.value ? ThemeMode.dark : ThemeMode.light,
        locale: localeOverride.value,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        // With no override, match the system language, falling back to English.
        localeResolutionCallback: (locale, supported) => supported.firstWhere(
          (s) => s.languageCode == locale?.languageCode,
          orElse: () => const Locale('en'),
        ),
        // Condensed font for the Ukrainian UI so long Cyrillic labels fit.
        builder: (context, child) =>
            Localizations.localeOf(context).languageCode == 'uk'
            ? Theme(data: AppTheme.withUkFont(Theme.of(context)), child: child!)
            : child!,
        home: const ScorePage(),
      ),
    );
  }
}
