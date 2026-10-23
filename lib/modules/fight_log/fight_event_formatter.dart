import '../../l10n/gen/app_localizations.dart';
import '../../utils/time_utils.dart';
import 'fight_event.dart';

/// Renders [event] as a localized log line, e.g. `"01:15.00 - 2 : 0"`.
String formatFightEvent(FightEvent event, AppLocalizations l10n) {
  final message = switch (event) {
    FightStarted() => l10n.logFightStarted,
    ScoreChanged(:final leftTotal, :final rightTotal) =>
      '$leftTotal : $rightTotal',
    PenaltyChanged(:final fighter, :final kind) => switch (kind) {
      PenaltyKind.warning => l10n.logWarningTo(fighter),
      PenaltyKind.caution => l10n.logCautionTo(fighter),
    },
    DoubleHitChanged() => l10n.logDoubleHit,
  };

  return '${formatTime(event.clock)} - $message';
}
