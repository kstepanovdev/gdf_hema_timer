import 'dart:async';
import 'package:flutter/material.dart';
import '../l10n/gen/app_localizations.dart';
import '../modules/opossum/tournament_store.dart';
import '../modules/opossum/outbox_sync.dart';

class OpossumOutboxPage extends StatefulWidget {
  const OpossumOutboxPage({
    super.key,
    required this.store,
    required this.origin,
    this.sync,
  });
  final TournamentStore store;
  final String origin;
  final OutboxSync? sync;
  @override
  State<OpossumOutboxPage> createState() => _OpossumOutboxPageState();
}

class _OpossumOutboxPageState extends State<OpossumOutboxPage> {
  List<OutboxEntry> _entries = [];
  bool _busy = false;
  bool _failed = false;
  bool _loading = false;
  Timer? _refresh;
  @override
  void initState() {
    super.initState();
    _load();
    _refresh = Timer.periodic(const Duration(seconds: 2), (_) => _load());
  }

  @override
  void dispose() {
    _refresh?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    if (_loading) return;
    _loading = true;
    try {
      final entries = await widget.store.entries(origin: widget.origin);
      if (mounted) {
        setState(() {
          _entries = entries;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      _loading = false;
    }
  }

  Future<void> _retry() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await widget.sync?.retry();
      if (mounted) setState(() => _failed = false);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      await _load();
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _handled(OutboxEntry entry) async {
    final l = AppLocalizations.of(context), reason = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(l.handledAtDesk),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l.handledExplanation),
            TextField(
              controller: reason,
              decoration: InputDecoration(labelText: l.reviewReason),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: Text(l.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: Text(l.confirmReview),
          ),
        ],
      ),
    );
    final value = reason.text;
    reason.dispose();
    if (confirmed != true || value.trim().isEmpty) return;
    try {
      await widget.store.handled(
        entry.request.clientEventId,
        value,
        DateTime.now(),
      );
      await _load();
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l.pendingResults),
        actions: [
          IconButton(
            tooltip: l.refresh,
            onPressed: _busy ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(l.outboxExplanation),
          if (widget.sync == null) Text(l.reconnectForSync),
          if (_failed)
            Text(
              l.durableStorageError,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          FilledButton(
            onPressed: _busy || widget.sync == null ? null : _retry,
            child: Text(_busy ? l.resultSending : l.retrySubmission),
          ),
          for (final e in _entries)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${e.snapshot.nomination.tournamentName} · ${e.snapshot.nomination.name}',
                    ),
                    Text(
                      '${e.snapshot.bout.context} · № ${e.snapshot.bout.sequence}',
                    ),
                    if (e.request.isJudge)
                      Text(
                        e.request.judgeEvent!['type'] == 'REMARK'
                            ? l.judgeRemark
                            : e.request.judgeEvent!['type'] == 'WARNING'
                            ? l.judgeWarning
                            : l.judgeMutualHit,
                      ),
                    Text(
                      '${e.snapshot.session.a.name} ${e.request.scoreA} : ${e.request.scoreB} ${e.snapshot.session.b.name}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(switch (e.state) {
                      OutboxState.pending => l.savedOnDevice,
                      OutboxState.retryPaused => l.retryPausedNotice,
                      OutboxState.sending => l.resultSending,
                      OutboxState.acknowledged => l.resultAccepted,
                      OutboxState.authentication => l.reconnectForSync,
                      OutboxState.conflict => l.apiConflict,
                      OutboxState.rejected => l.apiRejected,
                      OutboxState.handled => l.handledAtDesk,
                      OutboxState.cancelled => l.judgingCancelledLocal,
                    }),
                    if (e.errorCode != null)
                      Text('${l.syncReason}: ${e.errorCode}'),
                    if (e.dependencies.isNotEmpty &&
                        e.state == OutboxState.pending)
                      Text(l.dependencyNotice),
                    if (e.serverBout != null)
                      Text(
                        '${l.currentServerResult}: ${e.serverBout!.a?.name ?? "—"} ${e.serverBout!.scoreA ?? "—"} : ${e.serverBout!.scoreB ?? "—"} ${e.serverBout!.b?.name ?? "—"}',
                      ),
                    if ([
                          OutboxState.conflict,
                          OutboxState.rejected,
                        ].contains(e.state) ||
                        (e.state == OutboxState.pending &&
                            e.dependencies.any(
                              (id) => _entries.any(
                                (d) =>
                                    d.request.clientEventId == id &&
                                    [
                                      OutboxState.conflict,
                                      OutboxState.rejected,
                                      OutboxState.handled,
                                    ].contains(d.state),
                              ),
                            )))
                      TextButton(
                        onPressed: _busy ? null : () => _handled(e),
                        child: Text(l.handledAtDesk),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
