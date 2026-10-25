import 'dart:async';
import 'package:flutter/material.dart';
import '../l10n/gen/app_localizations.dart';
import '../modules/opossum/api_client.dart';
import '../modules/opossum/cached_client.dart';
import '../modules/opossum/connection_storage.dart';
import '../modules/opossum/error_message.dart';
import '../modules/opossum/models.dart';
import '../modules/opossum/pairing.dart';
import 'opossum_scan_page.dart';
import '../modules/opossum/outbox_sync.dart';
import '../modules/opossum/pending_submission.dart';
import '../modules/opossum/storage/open_store.dart';
import '../modules/opossum/tournament_store.dart';
import 'opossum_worklist_page.dart';
import 'opossum_outbox_page.dart';

class OpossumSetupPage extends StatefulWidget {
  const OpossumSetupPage({
    super.key,
    this.storage,
    this.createClient,
    this.repository,
    this.pairingTransport,
    this.scanQr,
  });
  final PairingTransport? pairingTransport;
  final Future<String?> Function(BuildContext)? scanQr;
  final ConnectionStorage? storage;
  final OpossumClient Function(ConnectionConfig)? createClient;
  final PendingSubmissionRepository? repository;
  @override
  State<OpossumSetupPage> createState() => _OpossumSetupPageState();
}

class _OpossumSetupPageState extends State<OpossumSetupPage> {
  final _url = TextEditingController(), _token = TextEditingController();
  final _pairingText = TextEditingController();
  late final PairingTransport _pairingTransport;
  TimerDeviceIdentity? _identity;
  late final ConnectionStorage _storage;
  PendingSubmissionRepository? _repository;
  TournamentStore? get _local =>
      _repository is TournamentStore ? _repository as TournamentStore : null;
  OpossumClient? _client;
  OutboxSync? _sync;
  final List<Future<void>> _retiring = [];
  String? _origin, _credentialRef;
  List<NominationRef>? _nominations;
  List<Json> _connections = [];
  int _pending = 0;
  bool _busy = false,
      _loading = true,
      _localHttp = false,
      _allowExit = false,
      _leaving = false,
      _cached = false;
  String? _errorKey;
  OpossumException? _error;
  @override
  void initState() {
    super.initState();
    _storage = widget.storage ?? PlatformConnectionStorage();
    _pairingTransport = widget.pairingTransport ?? HttpPairingTransport();
    _load();
  }

  Future<void> _load() async {
    try {
      _repository = widget.repository ?? await openTournamentStore();
      if (!mounted) {
        if (widget.repository == null) await _local?.close();
        return;
      }
      await _refreshLocal();
    } catch (_) {
      _errorKey = 'database';
    }
    try {
      final saved = await _storage.load(),
          savedUrl = await _storage.savedOrigin();
      if (!mounted) return;
      _url.text = saved?.baseUrl.toString() ?? savedUrl ?? '';
      if (saved != null) {
        _token.text = saved.token;
        _localHttp = saved.allowLocalHttp;
      }
    } catch (_) {
      _errorKey ??= 'storage';
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _refreshLocal() async {
    if (_local == null) return;
    final count = await _local!.unresolvedCount(),
        connections = await _local!.connections();
    if (mounted) {
      setState(() {
        _pending = count;
        _connections = connections;
      });
    }
  }

  void _retire() {
    if (_sync != null) {
      _retiring.add(_sync!.shutdown().catchError((Object _) {}));
    }
    _sync = null;
    _client?.close();
    _client = null;
  }

  void _invalidate() {
    _retire();
    setState(() => _nominations = null);
  }

  Future<int?> _pendingForDecision() async {
    try {
      await _refreshLocal();
      return _pending;
    } catch (_) {
      if (mounted) setState(() => _errorKey = 'database');
      return null;
    }
  }

  Future<bool> _confirmPending() async {
    if (_local == null) return true;
    final count = await _pendingForDecision();
    if (!mounted) return false;
    if (count == 0) return true;
    final l = AppLocalizations.of(context);
    return await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
            title: Text(l.pendingResults),
            content: Text('${l.pendingLeaveWarning}\n${count ?? "—"}'),
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
        ) ??
        false;
  }

  Future<void>? _pairOperation;
  bool _scanning = false;
  Future<void> _scan() async {
    if (_busy || _scanning) return;
    _scanning = true;
    try {
      final result =
          await (widget.scanQr?.call(context) ??
              Navigator.of(context).push<String>(
                MaterialPageRoute(
                  builder: (_) => OpossumScanPage(allowLocalHttp: _localHttp),
                ),
              ));
      if (result != null && mounted) {
        _pairingText.text = result;
        await _pair();
      }
    } finally {
      _scanning = false;
    }
  }

  Future<void> _pair() =>
      _pairOperation ??= _runPair().whenComplete(() => _pairOperation = null);
  Future<void> _runPair() async {
    if (_busy || _repository == null) return;
    if (!await _confirmPending() || !mounted) return;
    PairingLink link;
    try {
      link = PairingLink.parse(_pairingText.text, allowLocalHttp: _localHttp);
    } on FormatException {
      setState(() => _errorKey = 'pairing');
      return;
    }
    final l = AppLocalizations.of(context);
    final approved = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(l.pairingConfirm),
        content: Text('${link.origin}\n\n${l.repairEvidenceNotice}'),
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
    );
    if (approved != true || !mounted || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
      _errorKey = null;
    });
    var connected = false;
    try {
      final paired = await _pairingTransport.exchange(
        link,
        await _storage.deviceId(),
      );
      if (!mounted) return;
      _invalidate();
      _url.text = paired.config.baseUrl.toString();
      _token.text = paired.config.token;
      _identity = paired.identity;
      _pairingText.clear();
      try {
        await _storage.save(paired.config);
      } catch (_) {
        if (mounted) setState(() => _errorKey = 'storage');
        return;
      }
      connected = true;
    } on OpossumException catch (e) {
      if (mounted) setState(() => _error = e);
    } catch (_) {
      if (mounted) setState(() => _errorKey = 'storage');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (connected && mounted) await _test(confirmed: true);
  }

  Future<void> _test({bool confirmed = false}) async {
    if (_busy || _repository == null) return;
    if ((!confirmed && !await _confirmPending()) || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
      _errorKey = null;
      _nominations = null;
    });
    _retire();
    try {
      final config = ConnectionConfig(
        _url.text,
        _token.text,
        allowLocalHttp: _localHttp,
      );
      final raw = (widget.createClient ?? HttpOpossumClient.new)(config);
      _client = raw;
      final identity = raw is HttpOpossumClient ? await raw.identity() : null;
      final nominations = await raw.discover();
      if (!mounted) {
        raw.close();
        return;
      }
      try {
        await _storage.save(config);
      } catch (_) {
        if (mounted) setState(() => _errorKey = 'storage');
        return;
      }
      _origin = config.baseUrl.toString();
      _credentialRef = credentialFingerprint(config.token);
      if (_local != null) {
        await _local!.putMetadata('connection|$_origin', {
          'origin': _origin,
          'allow_local_http': config.allowLocalHttp,
          'credential_ref': _credentialRef,
          'device_id': await _storage.deviceId(),
        });
        await _local!.cacheDiscovery(_origin!, nominations);
        await _local!.retryTransport(_origin!);
        _client = CachedOpossumClient(
          network: raw,
          store: _local!,
          origin: _origin!,
        );
        _sync = OutboxSync(
          store: _local!,
          api: raw,
          origin: _origin!,
          credentialRef: _credentialRef!,
        )..start();
      }
      if (mounted) {
        setState(() {
          _nominations = nominations;
          _identity = identity;
          _cached = false;
        });
      }
      await _refreshLocal();
    } on FormatException {
      if (mounted) setState(() => _errorKey = 'config');
    } on OpossumException catch (e) {
      if (mounted) setState(() => _error = e);
    } catch (_) {
      if (mounted) setState(() => _errorKey = 'database');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _offline(Json connection) async {
    if (!await _confirmPending() || !mounted || _local == null) return;
    _retire();
    try {
      _origin = text(connection['origin']);
      _credentialRef = text(connection['credential_ref']);
      _url.text = _origin!;
      _localHttp = connection['allow_local_http'] == true;
      _client = CachedOpossumClient(
        network: DisconnectedClient(),
        store: _local!,
        origin: _origin!,
      );
      final nominations = await _client!.discover();
      if (mounted) {
        setState(() {
          _nominations = nominations;
          _cached = true;
          _error = null;
          _errorKey = null;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _errorKey = 'database');
    }
  }

  Future<void> _selectTournament(String id) async {
    if (!await _confirmPending() || !mounted) return;
    try {
      final deviceId = await _storage.deviceId();
      if (!mounted ||
          _client == null ||
          _origin == null ||
          _repository == null) {
        return;
      }
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => NominationSelectionPage(
            api: _client!,
            nominations: _nominations!
                .where((n) => n.tournamentId == id)
                .toList(),
            origin: _origin!,
            deviceId: deviceId,
            repository: _repository!,
            sync: _sync,
            credentialRef: _credentialRef,
          ),
        ),
      );
      await _refreshLocal();
    } catch (_) {
      if (mounted) setState(() => _errorKey = 'database');
    }
  }

  Future<void> _forget() async {
    if (!await _confirmPending() || !mounted) return;
    _invalidate();
    try {
      await _storage.forget();
      if (mounted) {
        _token.clear();
        _pairingText.clear();
        _identity = null;
        _url.clear();
        setState(() => _errorKey = null);
      }
    } catch (_) {
      if (mounted) setState(() => _errorKey = 'storage');
    }
  }

  Future<void> _leave() async {
    if (_leaving) return;
    _leaving = true;
    try {
      if (await _confirmPending() && mounted) {
        setState(() => _allowExit = true);
        Navigator.of(context).pop();
      }
    } finally {
      _leaving = false;
    }
  }

  @override
  void dispose() {
    _retire();
    if (widget.repository == null && _local != null) {
      final store = _local!;
      unawaited(Future.wait(_retiring).then((_) => store.close()));
    }
    _url.dispose();
    _token.dispose();
    _pairingText.dispose();
    _pairingTransport.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context),
        tournaments = <String, String>{
          for (final n in _nominations ?? <NominationRef>[])
            n.tournamentId: n.tournamentName,
        };
    return PopScope(
      canPop: _allowExit || _local == null,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) unawaited(_leave());
      },
      child: Scaffold(
        appBar: AppBar(title: Text(l.tournamentMode)),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Text(l.pairingIntro),
                  FilledButton.icon(
                    onPressed: _busy
                        ? null
                        : (supportsPairingCamera || widget.scanQr != null)
                        ? _scan
                        : null,
                    icon: const Icon(Icons.qr_code_scanner),
                    label: Text(l.scanPairingQr),
                  ),
                  if (!supportsPairingCamera) Text(l.cameraUnavailable),
                  TextField(
                    key: const Key('pairing-link'),
                    controller: _pairingText,
                    enabled: !_busy,
                    obscureText: true,
                    autocorrect: false,
                    enableSuggestions: false,
                    decoration: InputDecoration(labelText: l.pairingLink),
                  ),
                  TextButton(
                    onPressed: _busy ? null : _pair,
                    child: Text(l.usePairingLink),
                  ),
                  Text(l.manualConnection),
                  TextField(
                    key: const Key('opossum-url'),
                    controller: _url,
                    enabled: !_busy,
                    keyboardType: TextInputType.url,
                    autocorrect: false,
                    decoration: InputDecoration(
                      labelText: l.serverUrl,
                      hintText: 'https://opossum.example.org',
                    ),
                    onChanged: (_) => _invalidate(),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    key: const Key('opossum-token'),
                    controller: _token,
                    enabled: !_busy,
                    obscureText: true,
                    autocorrect: false,
                    enableSuggestions: false,
                    decoration: InputDecoration(labelText: l.deviceToken),
                    onChanged: (_) => _invalidate(),
                  ),
                  CheckboxListTile(
                    title: Text(l.localHttp),
                    value: _localHttp,
                    onChanged: _busy
                        ? null
                        : (value) {
                            _invalidate();
                            setState(() => _localHttp = value ?? false);
                          },
                  ),
                  if (!_storage.credentialsPersistent)
                    Text(l.browserTokenNotice),
                  if (_errorKey != null || _error != null)
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        _errorKey == 'pairing'
                            ? l.invalidPairingQr
                            : _errorKey == 'config'
                            ? l.invalidConnection
                            : _errorKey == 'database'
                            ? l.durableStorageError
                            : _errorKey == 'storage'
                            ? l.secureStorageError
                            : apiErrorMessage(_error!, l),
                        key: const Key('connection-error'),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  FilledButton(
                    onPressed: _busy || _repository == null ? null : _test,
                    child: Text(_busy ? l.resultSending : l.testConnection),
                  ),
                  TextButton(
                    onPressed: _busy ? null : _forget,
                    child: Text(l.forgetConnection),
                  ),
                  if (_local != null && !_local!.evictionProtected)
                    Text(l.browserPersistenceNotice),
                  if (_local != null) Text('${l.pendingResults}: $_pending'),
                  if (_local != null && _origin != null)
                    TextButton(
                      onPressed: () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => OpossumOutboxPage(
                              store: _local!,
                              origin: _origin!,
                              sync: _sync,
                            ),
                          ),
                        );
                        await _refreshLocal();
                      },
                      child: Text(l.pendingResults),
                    ),
                  for (final c in _connections)
                    ListTile(
                      leading: const Icon(Icons.offline_bolt),
                      title: Text(l.openSavedOffline),
                      subtitle: Text(text(c['origin'])),
                      onTap: _busy ? null : () => _offline(c),
                    ),
                  if (_cached) Text(l.cachedWorkWarning),
                  if (_identity != null)
                    Text(
                      '${_identity!.name} · ${_identity!.expiresAt?.toLocal() ?? "—"}',
                    ),
                  if (_nominations != null) ...[
                    Text(_cached ? l.offlineMode : l.connectionReady),
                    Text(
                      l.chooseTournament,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    if (tournaments.isEmpty) Text(l.noTournaments),
                    for (final e in tournaments.entries)
                      ListTile(
                        title: Text(e.value),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _selectTournament(e.key),
                      ),
                  ],
                ],
              ),
      ),
    );
  }
}

class NominationSelectionPage extends StatelessWidget {
  const NominationSelectionPage({
    super.key,
    required this.api,
    required this.nominations,
    required this.origin,
    required this.deviceId,
    required this.repository,
    this.sync,
    this.credentialRef,
  });
  final OpossumClient api;
  final List<NominationRef> nominations;
  final String origin, deviceId;
  final PendingSubmissionRepository repository;
  final OutboxSync? sync;
  final String? credentialRef;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(AppLocalizations.of(context).chooseNomination)),
    body: ListView(
      children: [
        for (final n in nominations)
          ListTile(
            title: Text(n.name),
            subtitle: Text(n.tournamentName),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => OpossumWorklistPage(
                  api: api,
                  nomination: n,
                  origin: origin,
                  deviceId: deviceId,
                  repository: repository,
                  sync: sync,
                  credentialRef: credentialRef,
                ),
              ),
            ),
          ),
      ],
    ),
  );
}
