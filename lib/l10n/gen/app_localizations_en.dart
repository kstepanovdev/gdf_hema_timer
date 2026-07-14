// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Scoreboard';

  @override
  String get reset => 'Reset';

  @override
  String get start => 'START';

  @override
  String get stop => 'Stop';

  @override
  String get warning => 'Warning';

  @override
  String get caution => 'Caution';

  @override
  String get double => 'Double';

  @override
  String get helpTitle => 'How to use';

  @override
  String get helpTap => 'Tap a number to add a point.';

  @override
  String get helpLongPress => 'Long-press a number to remove a point.';

  @override
  String get helpTimer => 'Long-press the timer to change the round time.';

  @override
  String get helpLog => 'Drag the log bar up to open the fight log.';

  @override
  String get helpResetScore =>
      'Long-press Reset to reset the score (keeps the time).';

  @override
  String get helpSettings =>
      'Swipe from the left edge to open Settings — dark theme, sounds, and this guide live there.';

  @override
  String get dontShowAgain => 'Don\'t show this again';

  @override
  String get continueLabel => 'Continue';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get darkTheme => 'Dark theme';

  @override
  String get yehorsSpecial => 'Yehor\'s special';

  @override
  String get yehorsSpecialSubtitle => 'Play a sound on Double hit';

  @override
  String get showTutorial => 'Show tutorial';

  @override
  String get language => 'Language';

  @override
  String get selectTime => 'Select Time';

  @override
  String get cancel => 'Cancel';

  @override
  String get ok => 'OK';

  @override
  String minutesLabel(int count) {
    return '$count m';
  }

  @override
  String secondsLabel(int count) {
    return '$count s';
  }

  @override
  String get dragUpForLogs => 'Drag up for logs';

  @override
  String get noEventsYet => 'No events yet';

  @override
  String get logFightStarted => 'Fight started';

  @override
  String logPointTo(String name) {
    return 'Point to $name';
  }

  @override
  String logWarningTo(String name) {
    return 'Warning to $name';
  }

  @override
  String logCautionTo(String name) {
    return 'Caution to $name';
  }

  @override
  String get logDoubleHit => 'Double hit';
}
