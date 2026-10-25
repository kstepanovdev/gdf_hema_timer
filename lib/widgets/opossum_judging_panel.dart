import 'package:flutter/material.dart';
import '../l10n/gen/app_localizations.dart';
import '../modules/bout_session/bout_session.dart';
import '../modules/opossum/error_message.dart';
import '../modules/opossum/judging.dart';
import '../modules/opossum/judging_controller.dart';
import '../modules/opossum/tournament_store.dart';

class OpossumJudgingPanel extends StatelessWidget {
  const OpossumJudgingPanel({
    super.key,
    required this.controller,
    this.refreshRelated,
  });
  final JudgingController controller;
  final Future<void> Function()? refreshRelated;
  String label(JudgeEventKind kind, AppLocalizations l) => switch (kind) {
    JudgeEventKind.remark => l.judgeRemark,
    JudgeEventKind.warning => l.judgeWarning,
    JudgeEventKind.mutualHit => l.judgeMutualHit,
  };
  Future<void> confirm(
    BuildContext context,
    JudgeEventKind kind,
    String? fighterId,
  ) async {
    final c = controller, l = AppLocalizations.of(context);
    c.session.pause();
    final basis = c.state!, captured = c.snapshot();
    var answered = false;
    final approved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.judgingConfirm),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label(kind, l)),
            if (fighterId != null)
              Text(
                fighterId == c.session.session.a.id
                    ? c.session.session.a.name
                    : c.session.session.b.name,
              ),
            Text(l.judgingConfirmExplanation),
            if (kind == JudgeEventKind.mutualHit &&
                c.state!.scoreSnapshotWrite &&
                c.bout.stageType != 'SINGLE_ELIMINATION')
              Text(
                l.judgingScoreSnapshot(
                  captured.session.a.score,
                  captured.session.b.score,
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              if (!answered) {
                answered = true;
                Navigator.pop(context, false);
              }
            },
            child: Text(l.cancel),
          ),
          FilledButton(
            key: const Key('confirm-judge-event'),
            onPressed: () {
              if (!answered) {
                answered = true;
                Navigator.pop(context, true);
              }
            },
            child: Text(l.confirmSubmit),
          ),
        ],
      ),
    );
    if (approved == true) {
      await c.confirm(
        kind,
        fighterId: fighterId,
        basis: basis,
        captured: captured,
      );
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final l = AppLocalizations.of(context), c = controller, state = c.state;
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Text(
                l.judgingTitle,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              if (c.unsavedRequest != null)
                FilledButton(
                  onPressed: c.busy ? null : c.retryLocalSave,
                  child: Text(l.retrySubmission),
                ),
              if (state == null) ...[
                Text(l.judgingUnavailable),
                if (c.error != null) Text(apiErrorMessage(c.error!, l)),
              ] else ...[
                Text(
                  l.judgingPolicy(
                    state.remarksPerWarning,
                    state.warningsForDisqualification,
                  ),
                ),
                Text(
                  l.judgingHitPolicy(
                    state.policy['threshold'] as int,
                    switch (state.policy['action']) {
                      'DOUBLE_LOSS' => l.judgingDoubleLossPolicy,
                      'DISABLED' => l.judgingDisabledPolicy,
                      'REFIGHT_UNTIL_DECISIVE' => l.judgingRefightPolicy,
                      'REFIGHTS_THEN_SUDDEN_DEATH' => l.judgingHybridPolicy,
                      'SUDDEN_DEATH' => l.judgingSuddenDeath,
                      _ => l.unavailableWork,
                    },
                  ),
                ),
                Text(switch (state.phase) {
                  'SUDDEN_DEATH' => l.judgingSuddenDeath,
                  'REFIGHT' => l.judgingRefight(state.attempt),
                  _ => l.judgingStandard,
                }),
                if (state.bout.resultType == 'DOUBLE_LOSS')
                  Text(
                    l.judgingDoubleLoss,
                    key: const Key('official-double-loss'),
                  ),
                if (state.fighters.any((f) => f.disqualified))
                  Text(l.judgingDisqualified),
                if (!state.judgeWrite) Text(l.judgingNoScope),
                if (state.mutualHit.reason == 'JUDGING_SCORES_REQUIRED')
                  Text(l.judgingScoresRequired),
                if (c.continuationReview) ...[
                  Text(l.judgingContinuationReview),
                  FilledButton(
                    onPressed: c.pending.isNotEmpty || c.blocked
                        ? null
                        : () async {
                            final accepted = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: Text(l.judgingContinuationTitle),
                                content: Text(l.judgingContinuationReview),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, false),
                                    child: Text(l.cancel),
                                  ),
                                  FilledButton(
                                    onPressed: () =>
                                        Navigator.pop(context, true),
                                    child: Text(l.judgingStartAttempt),
                                  ),
                                ],
                              ),
                            );
                            if (accepted == true) c.acceptContinuation();
                          },
                    child: Text(l.judgingStartAttempt),
                  ),
                ],
                Text(
                  '${l.judgeMutualHit}: ${state.bout.effectiveHits}',
                  key: const Key('official-mutual-hits'),
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                for (final side in DisplaySide.values) ...[
                  const Divider(),
                  Builder(
                    builder: (context) {
                      final fighter = c.session.at(side),
                          official = state.fighter(fighter.id);
                      return Column(
                        children: [
                          Text(
                            fighter.name,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          Text(
                            '${l.judgeRemark}: ${official.remarks} · ${l.judgeWarning}: ${official.warnings}',
                            key: Key('official-sanctions-${fighter.id}'),
                          ),
                          Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 8,
                            children: [
                              for (final kind in [
                                JudgeEventKind.remark,
                                JudgeEventKind.warning,
                              ])
                                FilledButton.tonalIcon(
                                  key: Key('judge-${kind.name}-${side.name}'),
                                  onPressed: c.canIssue(kind, fighter.id)
                                      ? () => confirm(context, kind, fighter.id)
                                      : null,
                                  icon: const Icon(Icons.add),
                                  label: Text(label(kind, l)),
                                ),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
                ],
                const SizedBox(height: 10),
                FilledButton.icon(
                  key: const Key('judge-mutual-hit'),
                  onPressed: c.canIssue(JudgeEventKind.mutualHit, null)
                      ? () => confirm(context, JudgeEventKind.mutualHit, null)
                      : null,
                  icon: const Icon(Icons.add),
                  label: Text(l.judgeMutualHit),
                ),
                if (c.offline || c.pending.isNotEmpty) Text(l.judgingOffline),
                if (c.blocked) Text(l.judgingSyncBlocked),
                if (c.competingState != null)
                  Text(
                    '${l.currentServerResult}: ${c.competingState!.bout.a?.name ?? "—"} ${c.competingState!.bout.scoreA ?? "—"}:${c.competingState!.bout.scoreB ?? "—"} ${c.competingState!.bout.b?.name ?? "—"}',
                  ),
                if (c.error != null) Text(apiErrorMessage(c.error!, l)),
                if (c.pending.isNotEmpty) ...[
                  Text(
                    '${l.judgingPending}: ${c.pending.length}',
                    key: const Key('pending-judge-events'),
                  ),
                  for (final e in c.pending)
                    ListTile(
                      title: Text(
                        '${e.request.judgeEvent!['type'] == 'REMARK'
                            ? l.judgeRemark
                            : e.request.judgeEvent!['type'] == 'WARNING'
                            ? l.judgeWarning
                            : l.judgeMutualHit}${e.request.judgeEvent!['participant_id'] == null ? '' : ' · ${e.request.judgeEvent!['participant_id'] == c.session.session.a.id ? c.session.session.a.name : c.session.session.b.name}'}',
                      ),
                      subtitle: Text(switch (e.state) {
                        OutboxState.conflict => l.apiConflict,
                        OutboxState.rejected => l.apiRejected,
                        OutboxState.authentication => l.apiAuthentication,
                        _ => l.savedOnDevice,
                      }),
                      trailing: !e.dispatched && e.state != OutboxState.sending
                          ? IconButton(
                              tooltip: l.judgingCancelLocal,
                              onPressed: c.busy
                                  ? null
                                  : () => c.cancelUnsent(e),
                              icon: const Icon(Icons.undo),
                            )
                          : null,
                    ),
                ],
                ExpansionTile(
                  title: Text(l.judgingHistory),
                  children: [
                    Text(l.judgingReview),
                    for (final r in state.records)
                      ListTile(
                        title: Text(
                          '${r['type'] == 'REMARK'
                              ? l.judgeRemark
                              : r['type'] == 'WARNING'
                              ? l.judgeWarning
                              : l.judgeMutualHit} · ${r['participant_id'] == c.session.session.a.id
                              ? c.session.session.a.name
                              : r['participant_id'] == c.session.session.b.id
                              ? c.session.session.b.name
                              : ''}',
                        ),
                        subtitle: SelectableText(
                          '${r['issued_at']}\n${r['record_id']}${r['voided_at'] == null ? '' : '\n${l.judgingRecordVoided}'}',
                        ),
                      ),
                  ],
                ),
              ],
              TextButton.icon(
                onPressed: c.loading
                    ? null
                    : () async {
                        await c.refresh();
                        await refreshRelated?.call();
                      },
                icon: const Icon(Icons.refresh),
                label: Text(l.refresh),
              ),
            ],
          ),
        ),
      );
    },
  );
}
