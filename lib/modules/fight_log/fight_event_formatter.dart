import '../../l10n/gen/app_localizations.dart';
import '../../utils/time_utils.dart';
import 'fight_event.dart';

/// Renders a structured [FightEvent] into a localized log line, e.g.
/// `"01:15 - Point to F1"`.
///
/// Pure function of the event plus the current localization — events are
/// self-describing (they carry the fighter's name). The exhaustive `switch`
/// over the sealed [FightEvent] type is checked by the compiler, so adding a
/// new event kind forces a matching message here.
String formatFightEvent(FightEvent event, AppLocalizations l10n) {
  final message = switch (event) {
    FightStarted() => l10n.logFightStarted,
    ScoreChanged(:final fighter) => l10n.logPointTo(fighter),
    PenaltyChanged(:final fighter, :final kind) => switch (kind) {
      PenaltyKind.warning => l10n.logWarningTo(fighter),
      PenaltyKind.caution => l10n.logCautionTo(fighter),
    },
    DoubleHitChanged() => l10n.logDoubleHit,
  };

  return '${formatTime(event.clock)} - $message';
}
