import 'dart:async';
import 'package:flutter/material.dart';
import '../l10n/gen/app_localizations.dart';
import '../modules/bout_session/bout_session_controller.dart';
import '../modules/opossum/api_client.dart';
import '../modules/opossum/error_message.dart';
import '../modules/opossum/models.dart';
import '../modules/opossum/bout_labels.dart';
import '../modules/opossum/pending_submission.dart';
import '../modules/opossum/submission_controller.dart';
import '../modules/opossum/worklist_controller.dart';
import '../modules/timer/storage.dart';
import 'opossum_result_page.dart';
import 'score_page.dart';
import 'opossum_outbox_page.dart';
import '../modules/opossum/tournament_store.dart';
import '../modules/opossum/session_recorder.dart';
import '../modules/opossum/judging_controller.dart';
import '../modules/opossum/session_snapshot.dart';
import '../widgets/opossum_judging_panel.dart';
import '../modules/opossum/outbox_sync.dart';
import '../modules/opossum/cached_client.dart';

class OpossumWorklistPage extends StatefulWidget {
  const OpossumWorklistPage({
    super.key,
    required this.api,
    required this.nomination,
    required this.origin,
    required this.deviceId,
    required this.repository,
    this.sync,
    this.credentialRef,
  });
  final OpossumClient api;
  final NominationRef nomination;
  final String origin, deviceId;
  final PendingSubmissionRepository repository;
  final OutboxSync? sync;
  final String? credentialRef;
  @override
  State<OpossumWorklistPage> createState() => _OpossumWorklistPageState();
}

class _OpossumWorklistPageState extends State<OpossumWorklistPage>
    with WidgetsBindingObserver {
  late final WorklistController _work;
  JudgingController? _judging;
  bool _opening = false;
  TournamentStore? get _local => widget.repository is TournamentStore
      ? widget.repository as TournamentStore
      : null;
  List<StoredDraft> _drafts = [];
  Set<String> _submitted = {};
  Map<String, OutboxState> _localStates = {};
  int _pending = 0;
  bool _localLoading = false, _localFailed = false;
  OpossumException? _openError;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _work = WorklistController(api: widget.api, nomination: widget.nomination);
    _work.addListener(_serverChanged);
    unawaited(_initialize());
  }

  Future<void> _initialize() async {
    if (_local != null) {
      try {
        final saved = await _local!.metadata(
          'selection|${widget.origin}|${widget.nomination.id}',
        );
        if (saved != null) _work.selectedPisteId = saved['piste_id'] as String?;
      } catch (_) {
        _localFailed = true;
      }
    }
    if (!mounted) return;
    await _loadLocal();
    if (mounted) _work.startPolling();
  }

  void _serverChanged() {
    if (!_work.loading) unawaited(_loadLocal());
  }

  Future<void> _loadLocal() async {
    if (_local == null || _localLoading) return;
    _localLoading = true;
    try {
      final drafts = await _local!.drafts(widget.origin, widget.nomination.id),
          entries = await _local!.entries(origin: widget.origin);
      if (mounted) {
        setState(() {
          _drafts = drafts;
          _submitted = entries
              .where((e) => !e.request.isJudge)
              .map((e) => e.request.boutId)
              .toSet();
          _localStates = {
            for (final e in entries.where((e) => !e.request.isJudge))
              e.request.boutId: e.state,
          };
          _pending = entries.where((e) => e.unresolved).length;
          _localFailed = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _localFailed = true);
    } finally {
      _localLoading = false;
    }
  }

  Future<void> _selectPiste(String id) async {
    if (_local != null) {
      await _loadLocal();
      if (!mounted) return;
      if (_pending > 0 || _localFailed) {
        final l = AppLocalizations.of(context);
        if (await showDialog<bool>(
              context: context,
              builder: (c) => AlertDialog(
                title: Text(l.pendingResults),
                content: Text('${l.pendingLeaveWarning}\n$_pending'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(c, false),
                    child: Text(l.cancel),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(c, true),
                    child: Text(l.continueLabel),
                  ),
                ],
              ),
            ) !=
            true) {
          return;
        }
      }
    }
    if (!_work.selectPiste(id)) return;
    if (_local != null) {
      try {
        await _local!.putMetadata(
          'selection|${widget.origin}|${widget.nomination.id}',
          {'piste_id': id},
        );
      } catch (_) {
        if (mounted) setState(() => _localFailed = true);
      }
    }
  }

  Future<void> _resume(StoredDraft saved) async {
    final b = saved.snapshot.bout;
    await _open(
      WorkItem.fromJson({
        'bout': b.toJson(),
        'readiness': 'READY',
        'order_key': [
          null,
          b.configurationSequence,
          b.executionStep,
          b.sequence,
        ],
      }),
      restored: saved,
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _work.startPolling();
    } else {
      _work.stopPolling();
    }
  }

  @override
  void dispose() {
    _judging?.dispose();
    WidgetsBinding.instance.removeObserver(this);
    _work.removeListener(_serverChanged);
    _work.dispose();
    super.dispose();
  }

  Future<void> _open(WorkItem item, {StoredDraft? restored}) async {
    if (_opening ||
        _work.activeBout != null ||
        (restored == null && (_work.loading || _work.error != null)) ||
        !item.selectable) {
      return;
    }
    final l10n = AppLocalizations.of(context);
    if (restored == null &&
        (item.bout.operational ||
            _work.selected?.recommendedBoutId != item.bout.id)) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: Text(
            item.bout.operational
                ? l10n.operationalSelection
                : l10n.otherReadyBout,
          ),
          content: Text(
            item.bout.operational
                ? '${item.bout.context} · ${timerBoutRole(item.bout, l10n)}\n${item.bout.a?.name ?? "—"} vs ${item.bout.b?.name ?? "—"}\n\n${l10n.operationalWarning}'
                : l10n.otherReadyExplanation,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: Text(l10n.continueLabel),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }
    if (_opening || _work.activeBout != null) return;
    setState(() {
      _opening = true;
      _openError = null;
    });
    BoutSessionController? controller;
    SessionRecorder? recorder;
    JudgingController? judging;
    try {
      if (_local != null &&
          await _local!.hasResult(widget.origin, item.bout.id)) {
        await _loadLocal();
        return;
      }
      final saved =
          restored ?? await _local?.draft(widget.origin, item.bout.id);
      final bout = saved?.snapshot.bout ?? await widget.api.bout(item.bout.id);
      if (!mounted) return;
      if (saved == null &&
          (bout.a?.id != item.bout.a?.id ||
              bout.b?.id != item.bout.b?.id ||
              bout.stageId != item.bout.stageId ||
              bout.groupId != item.bout.groupId ||
              bout.configurationId != item.bout.configurationId ||
              bout.pisteId != item.bout.pisteId ||
              !_work.begin(bout))) {
        throw const OpossumException(
          ApiFailure.rejected,
          code: 'BOUT_NOT_WRITABLE',
        );
      }
      if (saved != null && !_work.restoreDraft(bout)) return;
      if (widget.api is CachedOpossumClient &&
          (widget.api as CachedOpossumClient).offline &&
          saved == null) {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
            title: Text(l10n.offlineMode),
            content: Text(l10n.cachedWorkWarning),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: Text(l10n.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(c, true),
                child: Text(l10n.continueLabel),
              ),
            ],
          ),
        );
        if (confirmed != true || !mounted) return;
      }
      controller = BoutSessionController(
        duration: await loadTimerValue(),
        initialSession: bout.toSession(),
      );
      if (!mounted) return;
      final session = controller;
      if (saved != null) {
        session.restore(
          session: saved.snapshot.session,
          remaining: Duration(milliseconds: saved.snapshot.remainingMs),
          events: saved.snapshot.events,
          timingUncertain:
              saved.snapshot.wasRunning || saved.snapshot.timingUncertain,
        );
      }
      if (_local != null) {
        recorder = SessionRecorder(
          store: _local!,
          controller: session,
          origin: widget.origin,
          nomination: widget.nomination,
          bout: bout,
          configuredMs:
              saved?.snapshot.configuredMs ?? session.remaining.inMilliseconds,
          revision: saved?.revision ?? 0,
        )..checkpoint();
        await recorder.flush();
      }
      final recording = recorder;
      judging = JudgingController(
        api: widget.api,
        session: session,
        initialBout: bout,
        origin: widget.origin,
        deviceId: widget.deviceId,
        store: _local,
        sync: widget.sync,
        recorder: recording,
        credentialRef: widget.credentialRef,
        snapshot:
            recording?.snapshot ??
            () => SessionSnapshot(
              origin: widget.origin,
              nomination: widget.nomination,
              bout: bout,
              session: session.session,
              remainingMs: session.remaining.inMilliseconds,
              configuredMs: session.remaining.inMilliseconds,
              wasRunning: session.running,
              events: session.fightLog.events,
              savedAt: DateTime.now().toUtc(),
            ),
        onAcknowledged: _work.acknowledgeJudging,
      );
      final judgingSession = judging;
      _judging = judgingSession;
      await judgingSession.start();
      if (!mounted) return;
      await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (scoreContext) => AnimatedBuilder(
            animation: Listenable.merge([_work, ?recording, judgingSession]),
            builder: (_, _) => ScorePage(
              controller: session,
              durableSession: recording != null,
              judgingControls: OpossumJudgingPanel(
                controller: judgingSession,
                refreshRelated: _work.refresh,
              ),
              scoreEditingEnabled:
                  !judgingSession.terminal &&
                  !judgingSession.changed &&
                  !judgingSession.continuationReview,
              canReview: judgingSession.terminal || judgingSession.canReview,
              reviewLabel: judgingSession.terminal ? l10n.returnWorklist : null,
              beforeLeave: recording == null
                  ? null
                  : () async {
                      try {
                        if (judgingSession.unsavedRequest != null) {
                          await judgingSession.retryLocalSave();
                          if (judgingSession.unsavedRequest != null) {
                            return false;
                          }
                        }
                        await recording.flush();
                        return true;
                      } catch (_) {
                        return false;
                      }
                    },
              boutContext:
                  '${widget.nomination.tournamentName}\n${widget.nomination.name}\n${bout.context}${bout.operational ? " · ${timerBoutRole(bout, l10n)}" : ""} · № ${bout.sequence}',
              connectionStatus: Card(
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    children: [
                      if (widget.sync?.lastFailure != null)
                        Text(l10n.durableStorageError),
                      if (!judgingSession.canReview && !judgingSession.terminal)
                        Text(l10n.judgingWaitResult),
                      if (recording != null)
                        Text(
                          recording.error != null
                              ? l10n.durableStorageError
                              : recording.pending > 0
                              ? l10n.savingLocally
                              : l10n.draftSavedOnDevice,
                        ),
                      if (saved != null) Text(l10n.recoveredClockNotice),
                      if (widget.api is CachedOpossumClient &&
                          (widget.api as CachedOpossumClient).offline)
                        Text(l10n.cachedWorkWarning),
                      if (_work.activeChanged)
                        Semantics(
                          liveRegion: true,
                          child: Text(
                            l10n.activeBoutChanged,
                            style: TextStyle(
                              color: Theme.of(scoreContext).colorScheme.error,
                            ),
                          ),
                        ),
                      if (_work.error != null)
                        Text(apiErrorMessage(_work.error!, l10n)),
                      ExpansionTile(
                        title: Text(l10n.upcomingWork),
                        children: [
                          Text(l10n.activeBoutRetained),
                          for (final a
                              in _work.selected?.assignments ??
                                  <WorkAssignment>[])
                            ListTile(
                              title: Text(a.label),
                              subtitle: Text(
                                '${l10n.configurationLabel} ${a.configurationSequence ?? "—"} · ${_stateLabel(a.configurationStatus ?? a.group.status, l10n)}',
                              ),
                            ),
                        ],
                      ),
                      TextButton.icon(
                        onPressed: _work.loading ? null : _work.refresh,
                        icon: const Icon(Icons.refresh),
                        label: Text(l10n.refresh),
                      ),
                    ],
                  ),
                ),
              ),
              onReview: () async {
                session.pause();
                await judgingSession.reloadLocal();
                if (!scoreContext.mounted) return;
                if (judgingSession.terminal) {
                  Navigator.of(scoreContext).pop(true);
                  return;
                }
                if (!judgingSession.canReview) return;
                if (_work.activeChanged && _local == null) {
                  await showDialog<void>(
                    context: scoreContext,
                    builder: (c) => AlertDialog(
                      content: Text(l10n.activeBoutChanged),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(c),
                          child: Text(l10n.ok),
                        ),
                      ],
                    ),
                  );
                  return;
                }
                if (recording != null) {
                  try {
                    await recording.flush();
                  } catch (_) {
                    return;
                  }
                }
                if (!scoreContext.mounted) return;
                final submission = SubmissionController(
                  api: widget.api,
                  repository: widget.repository,
                  origin: widget.origin,
                  nomination: widget.nomination,
                  bout: judgingSession.bout,
                  session: session.session,
                  deviceId: widget.deviceId,
                  outbox: widget.sync,
                  snapshot: recording?.snapshot(),
                  credentialRef: widget.credentialRef,
                  expectedDraftRevision: recording?.revision,
                );
                final accepted = await Navigator.of(scoreContext).push<bool>(
                  MaterialPageRoute(
                    builder: (_) => OpossumResultPage(controller: submission),
                  ),
                );
                final finished =
                    accepted == true ||
                    submission.savedLocally ||
                    submission.receipt != null;
                submission.dispose();
                if (finished && scoreContext.mounted) {
                  Navigator.of(scoreContext).pop(true);
                }
              },
            ),
          ),
        ),
      );
    } on OpossumException catch (error) {
      if (mounted) setState(() => _openError = error);
    } catch (_) {
      if (mounted) setState(() => _localFailed = true);
    } finally {
      judging?.dispose();
      if (identical(_judging, judging)) _judging = null;
      if (recorder != null) {
        try {
          await recorder.flush();
        } catch (_) {}
        recorder.dispose();
      }
      controller?.dispose();
      if (mounted) {
        _work.end();
        setState(() => _opening = false);
        await _work.refresh();
      }
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _work,
    builder: (context, _) {
      final l10n = AppLocalizations.of(context),
          work = _work.work,
          piste = _work.selected;
      return Scaffold(
        appBar: AppBar(
          title: Text(l10n.worklist),
          actions: [
            IconButton(
              tooltip: l10n.refresh,
              onPressed: _work.loading ? null : _work.refresh,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(widget.nomination.tournamentName),
            Text(
              widget.nomination.name,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            Text(
              _local == null ? l10n.onlineOnlyNotice : l10n.durableModeNotice,
            ),
            if (_localFailed)
              Text(
                l10n.durableStorageError,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            if (widget.api is CachedOpossumClient &&
                (widget.api as CachedOpossumClient).offline)
              Text(
                '${l10n.cachedWorkWarning} · ${(widget.api as CachedOpossumClient).cachedAt?.toLocal() ?? "—"}',
              ),
            if (_local != null)
              TextButton.icon(
                onPressed: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => OpossumOutboxPage(
                        store: _local!,
                        origin: widget.origin,
                        sync: widget.sync,
                      ),
                    ),
                  );
                  await _loadLocal();
                },
                icon: const Icon(Icons.sync),
                label: Text('${l10n.pendingResults}: $_pending'),
              ),
            for (final draft in _drafts)
              ListTile(
                title: Text(
                  '${l10n.resumeSavedBout} · № ${draft.snapshot.bout.sequence}',
                ),
                subtitle: Text(draft.snapshot.bout.context),
                onTap: _opening ? null : () => _resume(draft),
              ),
            if (_work.loading || _opening) const LinearProgressIndicator(),
            if (_work.error != null || _openError != null)
              Semantics(
                liveRegion: true,
                child: Text(
                  apiErrorMessage((_openError ?? _work.error)!, l10n),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            if (work != null && work.pistes.isNotEmpty)
              DropdownButton<String>(
                key: const Key('physical-piste'),
                isExpanded: true,
                value: piste?.id,
                hint: Text(l10n.choosePiste),
                items: [
                  for (final p in work.pistes)
                    DropdownMenuItem(value: p.id, child: Text(p.name)),
                ],
                onChanged: _opening
                    ? null
                    : (id) {
                        if (id != null) unawaited(_selectPiste(id));
                      },
              ),
            if (work != null)
              Text('${l10n.serverRevision}: ${work.serverRevision}'),
            if (work != null && work.operational.isNotEmpty) ...[
              Text(
                l10n.operationalBouts,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              Text(l10n.operationalWarning),
              for (final item in work.operational)
                ListTile(
                  key: ValueKey('operational-${item.bout.id}'),
                  enabled:
                      !_opening &&
                      item.selectable &&
                      !_submitted.contains(item.bout.id),
                  title: Text(
                    '${item.bout.stageName} · ${timerBoutRole(item.bout, l10n)} · № ${item.bout.sequence}',
                  ),
                  subtitle: Text(
                    [
                      '${item.bout.a?.name ?? "—"} vs ${item.bout.b?.name ?? "—"}',
                      item.bout.groupName,
                      item.bout.pisteName ?? l10n.unassignedPiste,
                      item.bout.resultType == 'AUTO_WIN'
                          ? l10n.automaticWin
                          : _localStates[item.bout.id] != null
                          ? switch (_localStates[item.bout.id]) {
                              OutboxState.acknowledged => l10n.resultAccepted,
                              OutboxState.conflict => l10n.apiConflict,
                              OutboxState.rejected => l10n.apiRejected,
                              OutboxState.handled => l10n.handledAtDesk,
                              _ => l10n.savedOnDevice,
                            }
                          : item.bout.blockingCode == 'BRONZE_FIRST'
                          ? l10n.bronzeFirst
                          : item.selectable
                          ? l10n.readyBout
                          : _blocking(
                              item.bout.blockingCode ?? item.readiness,
                              l10n,
                            ),
                      if (item.bout.resultType == 'AUTO_WIN' &&
                          item.bout.automaticWinner != null)
                        item.bout.automaticWinner!.name,
                      if (item.bout.scoreA != null && item.bout.scoreB != null)
                        '${item.bout.scoreA} : ${item.bout.scoreB}',
                    ].whereType<String>().join(' · '),
                  ),
                  trailing: item.selectable
                      ? const Icon(Icons.play_arrow)
                      : const Icon(Icons.info_outline),
                  onTap: () => _open(item),
                ),
            ],
            if (piste != null) ...[
              Text(l10n.recommendationHint),
              for (final g in piste.groups.where(
                (g) => !piste.assignments.any((a) => a.groupId == g.id),
              ))
                ListTile(
                  title: Text(g.name),
                  subtitle: Text(_groupProgress(g, l10n)),
                ),
              if (piste.assignments.isEmpty) Text(l10n.noWork),
              for (final a in piste.assignments)
                _assignment(context, work!, piste, a),
            ],
          ],
        ),
      );
    },
  );
  Widget _assignment(
    BuildContext context,
    TimerWorklist work,
    PisteWorklist piste,
    WorkAssignment a,
  ) {
    final l = AppLocalizations.of(context);
    final active =
        a.configurationStatus == 'ACTIVE' &&
        a.group.status == 'STARTED' &&
        a.stage.status == 'IN_PROGRESS';
    final previous = work.configurations
        .where(
          (c) =>
              c.groupId == a.groupId &&
              c.sequence == (a.configurationSequence ?? 0) - 1,
        )
        .firstOrNull;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              header: true,
              child: Text(
                a.label,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            if (a.wave != null) Text('${a.wave!.name} · ${a.wave!.order}'),
            Text(
              '${_stateLabel(a.stage.status, l)} · ${_stateLabel(a.group.status, l)}',
            ),
            if (a.configurationSequence != null)
              Text(
                '${l.configurationLabel} ${a.configurationSequence}/${a.configurationCount} · ${_stateLabel(a.configurationStatus!, l)}',
              ),
            if (!active)
              Text(
                a.stage.status == 'DRAFT' || a.stage.status == 'SCHEDULED'
                    ? l.waitingStage
                    : a.group.status == 'GENERATED'
                    ? l.waitingGroup
                    : l.waitingConfiguration,
              ),
            if (active && a.remainingHere == 0 && a.remainingElsewhere > 0)
              Text('${l.waitingOtherPistes}: ${a.remainingElsewhere}'),
            if (a.fightersHere.isNotEmpty)
              Text(
                '${l.fightersHere}: ${a.fightersHere.map((f) => f.name).join(", ")}',
              ),
            if (active && previous != null) ...[
              Text(
                l.fightersChanged,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              Text(
                '${l.fightersLeaving}: ${(previous.populations[a.pisteId] ?? []).where((id) => !a.fightersHere.any((f) => f.id == id)).map(work.fighterName).join(", ")}',
              ),
              Text(
                '${l.fightersArriving}: ${a.fightersHere.where((f) => !(previous.populations[a.pisteId] ?? []).contains(f.id)).map((f) => f.name).join(", ")}',
              ),
            ],
            if (previous != null)
              ExpansionTile(
                title: Text(
                  '${l.previousConfiguration} ${previous.sequence} → ${a.configurationSequence}',
                ),
                children: [
                  Text(
                    '${l.previousPopulation}: ${(previous.populations[a.pisteId] ?? []).map(work.fighterName).join(", ")}',
                  ),
                  Text(
                    '${l.currentPopulation}: ${a.fightersHere.map((f) => f.name).join(", ")}',
                  ),
                ],
              ),
            if (a.nextPopulation != null)
              ExpansionTile(
                title: Text(
                  '${l.nextConfiguration} ${(a.configurationSequence ?? 0) + 1}',
                ),
                subtitle: Text(l.transitionAuthority),
                children: [
                  Text(
                    '${l.nextPopulation}: ${a.nextPopulation!.map((f) => f.name).join(", ")}',
                  ),
                  for (final m in a.movesAfter)
                    ListTile(
                      dense: true,
                      title: Text(m.fighter.name),
                      subtitle: Text(
                        '${work.pisteName(m.fromPisteId)} → ${work.pisteName(m.toPisteId)}',
                      ),
                    ),
                  Text(
                    '${l.remainingHere}: ${a.remainingHere} · ${l.remainingElsewhere}: ${a.remainingElsewhere}',
                  ),
                ],
              ),
            for (final i in a.items)
              ListTile(
                key: ValueKey('bout-${i.bout.id}'),
                leading: i.bout.id == piste.recommended?.bout.id
                    ? Tooltip(
                        message: l.recommendedNext,
                        child: const Icon(Icons.play_circle_outline),
                      )
                    : null,
                title: Text(
                  '№ ${i.bout.sequence} · ${i.bout.a?.name ?? "—"} vs ${i.bout.b?.name ?? "—"}',
                ),
                subtitle: Text(
                  _localStates.containsKey(i.bout.id)
                      ? switch (_localStates[i.bout.id]) {
                          OutboxState.acknowledged => l.resultAccepted,
                          OutboxState.conflict => l.apiConflict,
                          OutboxState.rejected => l.apiRejected,
                          OutboxState.handled => l.handledAtDesk,
                          _ => l.savedOnDevice,
                        }
                      : '${i.bout.id == piste.recommended?.bout.id ? "${l.recommendedNext} · " : ""}${i.selectable ? l.readyBout : _blocking(i.bout.blockingCode ?? i.readiness, l)}${i.bout.executionStep == null ? "" : " · ${l.executionStep} ${i.bout.executionStep}"}',
                ),
                enabled:
                    !_submitted.contains(i.bout.id) &&
                    i.selectable &&
                    !_opening &&
                    !_work.loading &&
                    _work.error == null,
                onTap: () => _open(i),
              ),
          ],
        ),
      ),
    );
  }
}

String _stateLabel(String code, AppLocalizations l) => switch (code) {
  'ACTIVE' || 'STARTED' || 'IN_PROGRESS' => l.activeWork,
  'PLANNED' => l.plannedWork,
  'GENERATED' => l.waitingGroup,
  'NOT_GENERATED' => l.awaitingSchedule,
  'COMPLETED' || 'FINALIZED' => l.completedWork,
  'DRAFT' || 'SCHEDULED' => l.waitingStage,
  _ => l.unavailableWork,
};
String _blocking(String code, AppLocalizations l) => switch (code) {
  'START_STAGE' => l.waitingStage,
  'START_GROUP' => l.waitingGroup,
  'CONFIGURATION' => l.waitingConfiguration,
  'COMPLETED' => l.completedWork,
  'CANCELLED' => l.cancelledWork,
  'VOID' => l.voidWork,
  'STAGE_LOCKED' => l.stageLocked,
  _ => l.unavailableWork,
};

String _groupProgress(WorkGroup g, AppLocalizations l) => switch (g.progress) {
  'READY_TO_COMPLETE' => l.waitingGroupCompletion,
  'TIE_BREAK_REQUIRED' || 'TIE_BREAK_IN_PROGRESS' => l.waitingTieBreak,
  'PISTE_SHEET_OPEN' => l.waitingJudgeSheet,
  'COMPLETED' => l.completedWork,
  _ => _stateLabel(g.status, l),
};
