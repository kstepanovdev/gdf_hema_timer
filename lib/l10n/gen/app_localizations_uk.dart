// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Ukrainian (`uk`).
class AppLocalizationsUk extends AppLocalizations {
  AppLocalizationsUk([String locale = 'uk']) : super(locale);

  @override
  String get appTitle => 'Табло';

  @override
  String get reset => 'Скинути';

  @override
  String get start => 'СТАРТ';

  @override
  String get stop => 'Стоп';

  @override
  String get warning => 'Зауваження';

  @override
  String get caution => 'Попередження';

  @override
  String get double => 'Обопільні';

  @override
  String get helpTitle => 'Як користуватися';

  @override
  String get helpTap => 'Торкніться числа, щоб додати очко.';

  @override
  String get helpLongPress => 'Утримуйте число, щоб зняти очко.';

  @override
  String get helpTimer => 'Утримуйте таймер, щоб змінити час раунду.';

  @override
  String get helpLog =>
      'Потягніть панель журналу вгору, щоб відкрити журнал бою.';

  @override
  String get helpResetScore =>
      'Утримуйте «Скинути», щоб скинути рахунок (час залишиться).';

  @override
  String get helpSettings =>
      'Проведіть від лівого краю, щоб відкрити налаштування — темна тема, звуки та ця підказка там.';

  @override
  String get dontShowAgain => 'Більше не показувати';

  @override
  String get continueLabel => 'Продовжити';

  @override
  String get settingsTitle => 'Налаштування';

  @override
  String get darkTheme => 'Темна тема';

  @override
  String get yehorsSpecial => 'Спеціально для Єгора';

  @override
  String get yehorsSpecialSubtitle => 'Відтворювати звук при обопільному ударі';

  @override
  String get showTutorial => 'Показати підказку';

  @override
  String get language => 'Мова';

  @override
  String get selectTime => 'Оберіть час';

  @override
  String get cancel => 'Скасувати';

  @override
  String get ok => 'OK';

  @override
  String minutesLabel(int count) {
    return '$count хв';
  }

  @override
  String secondsLabel(int count) {
    return '$count с';
  }

  @override
  String get secondsShort => 'с';

  @override
  String get dragUpForLogs => 'Потягніть вгору для журналу';

  @override
  String get noEventsYet => 'Поки немає подій';

  @override
  String get logFightStarted => 'Бій розпочато';

  @override
  String logPointTo(String name) {
    return 'Очко для $name';
  }

  @override
  String logWarningTo(String name) {
    return 'Зауваження для $name';
  }

  @override
  String logCautionTo(String name) {
    return 'Попередження для $name';
  }

  @override
  String get logDoubleHit => 'Обопільний удар';
}
