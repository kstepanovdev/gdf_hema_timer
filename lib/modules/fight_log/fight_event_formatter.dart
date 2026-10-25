import '../../l10n/gen/app_localizations.dart';
import '../../utils/time_utils.dart';
import 'fight_event.dart';

/// Renders a structured [FightEvent] into a localized log line, e.g.
/// `"01:15 - 2 : 0"`.
///
/// Pure function of the event plus the current localization — events are
/// self-describing (they carry the fighter's name). The exhaustive `switch`
/// over the sealed [FightEvent] type is checked by the compiler, so adding a
/// new event kind forces a matching message here.
String formatFightEvent(FightEvent event, AppLocalizations l10n) {
  final message = switch (event) {
    FightStarted() => l10n.logFightStarted,
    ScoreChanged(
      :final fighter,
      :final delta,
      :final leftTotal,
      :final rightTotal,
    ) =>
      '$fighter ${delta > 0 ? '+' : ''}$delta · $leftTotal : $rightTotal',
    PenaltyChanged(:final fighter, :final kind, :final delta, :final total) =>
      switch (kind) {
        PenaltyKind.warning =>
          '${l10n.logWarningTo(fighter)} ${delta > 0 ? '+' : ''}$delta ($total)',
        PenaltyKind.caution =>
          '${l10n.logCautionTo(fighter)} ${delta > 0 ? '+' : ''}$delta ($total)',
      },
    DoubleHitChanged(:final delta, :final total) =>
      '${l10n.logDoubleHit} ${delta > 0 ? '+' : ''}$delta ($total)',
    SessionChanged(:final action) => switch (action) {
      SessionAction.paused => l10n.logPaused,
      SessionAction.resumed => l10n.logResumed,
      SessionAction.elapsed => l10n.logElapsed,
      SessionAction.interrupted => l10n.logInterrupted,
      SessionAction.timeAdjusted => l10n.logTimeAdjusted,
      SessionAction.sidesSwapped => l10n.logSidesSwapped,
      SessionAction.reset => l10n.logReset,
    },
  };

  return '${formatTime(event.clock)} - $message';
}
