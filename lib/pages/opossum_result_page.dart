import 'package:flutter/material.dart';
import '../l10n/gen/app_localizations.dart';
import '../modules/opossum/error_message.dart';
import '../modules/opossum/pending_submission.dart';
import '../modules/opossum/bout_labels.dart';
import '../modules/opossum/submission_controller.dart';

class OpossumResultPage extends StatelessWidget {
  const OpossumResultPage({super.key, required this.controller});
  final SubmissionController controller;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final l10n = AppLocalizations.of(context), c = controller;
      final supportedHits = c.session.mutualHits == c.bout.effectiveHits;
      final accepted = c.receipt != null;
      final uncertain = [
        SubmissionState.uncertain,
        SubmissionState.sending,
        SubmissionState.rateLimited,
      ].contains(c.state);
      return PopScope(
        canPop: c.savedLocally || !uncertain,
        child: Scaffold(
          appBar: AppBar(
            title: Text(l10n.reviewResult),
            automaticallyImplyLeading: c.savedLocally || !uncertain,
          ),
          body: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(c.nomination.tournamentName),
              Text(c.nomination.name),
              Text('${c.bout.context} · № ${c.bout.sequence}'),
              if (c.bout.operational) Text(timerBoutRole(c.bout, l10n)),
              const SizedBox(height: 16),
              Column(
                key: const Key('review-score'),
                children: [
                  for (final fighter in [c.session.a, c.session.b])
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            fighter.name,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Text(
                          '${fighter.score}',
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                      ],
                    ),
                ],
              ),
              Text(
                c.session.a.score == c.session.b.score
                    ? l10n.drawResult
                    : l10n.normalResult,
              ),
              Text(l10n.judgingResultReview),
              if (c.savedLocally && !accepted)
                Text(l10n.savedOnDevice, key: const Key('saved-on-device')),
              if (!c.repository.durable)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(l10n.onlineOnlyNotice),
                ),
              if (!supportedHits)
                Text(
                  l10n.unsupportedHits,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              Semantics(
                liveRegion: true,
                child: Text(
                  accepted
                      ? (c.receipt!.replayed == true
                            ? l10n.duplicateAccepted
                            : c.receipt!.replayed == null &&
                                  c.state == SubmissionState.accepted &&
                                  c.attempts > 1
                            ? l10n.acceptedAfterRetry
                            : l10n.resultAccepted)
                      : c.sending
                      ? l10n.resultSending
                      : c.request == null
                      ? l10n.resultPending
                      : uncertain
                      ? l10n.resultUncertain
                      : l10n.resultUnconfirmed,
                  key: const Key('submission-status'),
                ),
              ),
              if (c.error != null)
                Semantics(
                  liveRegion: true,
                  child: Text(
                    apiErrorMessage(c.error!, l10n),
                    key: const Key('submission-error'),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              if (c.error?.currentBout != null)
                Text(
                  '${l10n.currentServerResult}: ${c.error!.currentBout!.a?.name} ${c.error!.currentBout!.scoreA ?? "—"} : ${c.error!.currentBout!.scoreB ?? "—"} ${c.error!.currentBout!.b?.name}',
                ),
              if (c.refreshFailed) ...[
                Text(l10n.refreshFailed),
                TextButton(
                  onPressed: c.sending ? null : c.refresh,
                  child: Text(l10n.refresh),
                ),
              ],
              if (accepted || c.savedLocally)
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: Text(l10n.returnWorklist),
                )
              else if (c.request == null || c.canRetry)
                FilledButton(
                  key: const Key('confirm-result'),
                  onPressed: c.sending || !supportedHits ? null : c.confirm,
                  child: Text(
                    c.request == null
                        ? l10n.confirmSubmit
                        : l10n.retrySubmission,
                  ),
                ),
            ],
          ),
        ),
      );
    },
  );
}
