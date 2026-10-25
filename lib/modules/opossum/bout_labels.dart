import '../../l10n/gen/app_localizations.dart';
import 'models.dart';

String timerBoutRole(TimerBout bout, AppLocalizations l) {
  if (bout.purpose == 'TIE_BREAK') {
    return '${bout.groupId == null ? l.stageTieBreak : l.groupTieBreak} · ${bout.tieBreakSequence ?? "—"}';
  }
  return switch (bout.bracketRole) {
    'SEMIFINAL' => l.semifinalBout,
    'BRONZE' => l.bronzeBout,
    'FINAL' => l.goldBout,
    'ROUND' => '${l.eliminationRound} ${bout.bracketRound ?? "—"}',
    _ => '',
  };
}
