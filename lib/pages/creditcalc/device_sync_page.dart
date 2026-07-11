import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../offline/device_transfer/device_transfer_config.dart';
import '../../offline/device_transfer/device_transfer_models.dart';
import '../../offline/device_transfer/device_transfer_service.dart';
import '../../offline/services/connectivity_service.dart';
import '../../ui/layout/page_shell.dart';

class DeviceSyncPage extends StatefulWidget {
  const DeviceSyncPage({super.key});

  @override
  State<DeviceSyncPage> createState() => _DeviceSyncPageState();
}

class _DeviceSyncPageState extends State<DeviceSyncPage>
    with WidgetsBindingObserver {
  bool _loading = true;
  bool _busy = false;
  bool _online = true;
  bool _isSender = false;
  bool _receiverReady = false;
  DeviceTransferMeta? _activeTransfer;
  DeviceTransferLocalState? _localState;
  DeviceTransferPeerState? _peer;
  DeviceTransferSyncHint _syncHint = DeviceTransferSyncHint.waitingForPeer;
  String? _statusMessage;
  String? _error;
  DeviceTransferReceiveResult? _lastReceive;
  int _recordsToSendToPeer = 0;
  int _recordsPeerWouldSend = 0;
  StreamSubscription<bool>? _receiverSub;
  StreamSubscription<DeviceTransferPeerState?>? _peerSub;
  StreamSubscription<DeviceTransferMeta?>? _transferSub;
  Timer? _presenceTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void activate() {
    super.activate();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      unawaited(_refreshLocalExchangeState(uid));
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        unawaited(_refreshLocalExchangeState(uid));
      }
    }
  }

  Future<void> _refreshLocalExchangeState(String uid) async {
    try {
      if (_online) {
        await DeviceTransferService.pingReceiverPresence(uid);
      }
      final localState = await DeviceTransferService.readLocalState(uid);
      if (!mounted) return;
      setState(() {
        _localState = localState;
        if (_peer == null) {
          _syncHint = DeviceTransferSyncAdvisor.advise(
            local: localState,
            peer: null,
            exchange: null,
          );
        }
      });
      await _updateExchangeCounts(uid);
    } catch (_) {}
  }

  int get _effectiveSendCount {
    final pending = _localState?.pendingChangeCount ?? 0;
    return _recordsToSendToPeer > pending
        ? _recordsToSendToPeer
        : pending;
  }

  int get _localChangeEstimate {
    final local = _localState;
    if (local == null) return 0;
    return local.pendingChangeCount;
  }

  bool get _hasPackageInTransit =>
      _isSender && _activeTransfer?.isPending == true;

  int get _inTransitRecordCount =>
      _hasPackageInTransit ? _activeTransfer!.recordCount : 0;

  String get _displaySendCount {
    if (_hasPackageInTransit) {
      final remaining = _effectiveSendCount - _inTransitRecordCount;
      if (remaining > 0) return '$remaining (+$_inTransitRecordCount in transito)';
      return '$_inTransitRecordCount in transito';
    }
    if (_peer != null) return '$_effectiveSendCount';
    return '—';
  }

  String get _sendRowLabel {
    if (_hasPackageInTransit) return 'In attesa di ricezione sull\'altro';
    return 'Da inviare all\'altro';
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _receiverSub?.cancel();
    _peerSub?.cancel();
    _transferSub?.cancel();
    _presenceTimer?.cancel();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      unawaited(DeviceTransferService.clearReceiverPresence(uid));
    }
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final uid = FirebaseAuth.instance.currentUser?.uid;
    final online = await ConnectivityService.isOnline();
    DeviceTransferMeta? transfer;
    DeviceTransferLocalState? localState;
    DeviceTransferPeerState? peer;
    var isSender = false;

    if (uid != null) {
      try {
        localState = await DeviceTransferService.readLocalState(uid);
      } catch (_) {}
      if (online) {
        try {
          peer = await DeviceTransferService.readPeerState(uid);
          peer ??= await DeviceTransferService.readPeerState(
            uid,
            preferServer: true,
          );
          transfer = await DeviceTransferService.readTransferMeta(uid);
          if (transfer?.isPrepared == true || transfer?.isPending == true) {
            isSender = await DeviceTransferService.isActiveSender(uid);
          }
        } catch (_) {}
      }
    }

    DeviceTransferExchangeCounts? exchange;
    if (uid != null && peer != null) {
      exchange = await DeviceTransferService.exchangeCounts(uid, peer);
    }

    final syncHint = localState == null
        ? DeviceTransferSyncHint.waitingForPeer
        : DeviceTransferSyncAdvisor.advise(
            local: localState,
            peer: peer,
            exchange: exchange,
          );

    if (!mounted) return;
    setState(() {
      _online = online;
      _activeTransfer = _effectiveTransfer(transfer);
      _localState = localState;
      _peer = peer;
      _isSender = isSender;
      _syncHint = syncHint;
      _loading = false;
    });

    if (uid != null) {
      await _updateExchangeCounts(uid);
    }

    await _syncPresenceAndWatch(uid, isSender);
  }

  Future<void> _updateExchangeCounts(String uid) async {
    final peer = _peer;
    if (peer == null) {
      if (!mounted) return;
      setState(() {
        _recordsToSendToPeer = 0;
        _recordsPeerWouldSend = 0;
      });
      return;
    }
    try {
      final counts = await DeviceTransferService.exchangeCounts(uid, peer);
      if (!mounted) return;
      setState(() {
        _recordsToSendToPeer = counts.localToSend;
        _recordsPeerWouldSend = counts.peerToSend;
        final local = _localState;
        if (local != null) {
          _syncHint = DeviceTransferSyncAdvisor.advise(
            local: local,
            peer: peer,
            exchange: counts,
          );
        }
      });
    } catch (_) {}
  }

  Future<void> _syncPresenceAndWatch(String? uid, bool isSender) async {
    await _receiverSub?.cancel();
    await _peerSub?.cancel();
    await _transferSub?.cancel();
    _receiverSub = null;
    _peerSub = null;
    _transferSub = null;
    _presenceTimer?.cancel();
    _presenceTimer = null;

    if (uid == null || !_online) return;

    try {
      await DeviceTransferService.pingReceiverPresence(uid);
    } catch (_) {}
    _presenceTimer = Timer.periodic(
      const Duration(seconds: DeviceTransferConfig.presenceHeartbeatSeconds),
      (_) {
        unawaited(DeviceTransferService.pingReceiverPresence(uid));
        unawaited(_refreshLocalExchangeState(uid));
      },
    );

    _peerSub = DeviceTransferService.watchPeerState(uid).listen((peer) {
      if (!mounted) return;
      setState(() => _peer = peer);
      unawaited(_updateExchangeCounts(uid));
    });

    _transferSub = DeviceTransferService.watchTransferMeta(uid).listen(
      (transfer) => unawaited(_applyTransferMeta(uid, transfer)),
    );

    await _startReceiverReadyWatch(uid, isSender);
  }

  Future<void> _applyTransferMeta(
    String uid,
    DeviceTransferMeta? transfer,
  ) async {
    var isSender = false;
    if (transfer?.isPrepared == true || transfer?.isPending == true) {
      isSender = await DeviceTransferService.isActiveSender(uid);
    }
    if (!mounted) return;
    final wasSender = _isSender;
    setState(() {
      _activeTransfer = _effectiveTransfer(transfer);
      _isSender = isSender;
      if (transfer?.isReceivable == true &&
          !isSender &&
          !_isPackageAlreadyReceived(transfer!)) {
        _statusMessage =
            'Pacchetto pronto da ricevere. Tocca «Ricevi dati» '
            'entro ${DeviceTransferFormat.dateTime(
              DateTime.fromMillisecondsSinceEpoch(transfer.expiresAtMs),
            )}.';
      } else if (transfer?.isPending == true && isSender) {
        _statusMessage =
            'Pacchetto di ${transfer!.recordCount} record inviato. '
            'Sull\'altro dispositivo tocca «Ricevi dati».\n\n'
            'Il contatore qui può restare alto finché l\'altro non riceve.';
      }
    });

    if (wasSender != isSender) {
      await _startReceiverReadyWatch(uid, isSender);
    }
  }

  Future<void> _startReceiverReadyWatch(String uid, bool isSender) async {
    await _receiverSub?.cancel();
    _receiverSub = null;
    if (!isSender) return;

    _receiverSub = DeviceTransferService.watchReceiverReady(uid).listen(
      (ready) {
        if (!mounted) return;
        setState(() {
          _receiverReady = ready;
          if (ready &&
              _statusMessage?.contains('Altro dispositivo') != true) {
            _statusMessage =
                'Altro dispositivo rilevato con lo stesso account. '
                'Ora puoi inviare i dati.';
          }
        });
      },
    );
  }

  Future<void> _sendUpdatesToPeer() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    setState(() {
      _busy = true;
      _error = null;
      _statusMessage = 'Invio aggiornamenti all\'altro dispositivo…';
      _lastReceive = null;
      _receiverReady = false;
    });

    try {
      final prepared = await DeviceTransferService.preparePackage(uid);
      if (!mounted) return;
      setState(() {
        _statusMessage =
            'Invio di ${prepared.recordCount} record '
            '(${DeviceTransferFormat.bytes(prepared.totalBytes)})…';
      });
      final result = await DeviceTransferService.releasePackage(uid);
      if (!mounted) return;
      setState(() {
        _statusMessage =
            'Inviati ${result.recordCount} record. Sull\'altro dispositivo '
            'tocca «Ricevi dati» entro '
            '${DeviceTransferFormat.dateTime(result.expiresAt)}.\n\n'
            'Il contatore qui resterà alto finché l\'altro non riceve: '
            'è normale. Dopo la ricezione si aggiorna da solo.\n\n'
            'Se l\'altro ha ancora record da inviare, ripeti da quel dispositivo.';
      });
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _release() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    setState(() {
      _busy = true;
      _error = null;
      _statusMessage = 'Invio pacchetto in corso…';
    });

    try {
      final result = await DeviceTransferService.releasePackage(uid);
      if (!mounted) return;
      setState(() {
        _statusMessage =
            'Dati inviati. Sul secondo dispositivo tocca «Ricevi dati» '
            'entro ${DeviceTransferFormat.dateTime(result.expiresAt)}.';
      });
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _receive() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    setState(() {
      _busy = true;
      _error = null;
      _statusMessage = 'Download e importazione in corso…';
    });

    try {
      final result = await DeviceTransferService.receiveOnThisDevice(uid);
      if (!mounted) return;
      setState(() {
        _activeTransfer = null;
        _lastReceive = result;
      });
      await _refresh();
      if (!mounted) return;
      final followUp = _recordsToSendToPeer > 0
          ? 'Se hai ancora record da inviare, tocca «Invia aggiornamenti».'
          : _recordsPeerWouldSend > 0
              ? 'L\'altro dispositivo può ancora inviare: ripeti lì.'
              : 'I dispositivi risultano allineati.';
      setState(() {
        _statusMessage =
            'Ricevuti ${result.importedRecords} record '
            '(${DeviceTransferFormat.bytes(result.totalBytes)}).\n\n'
            '$followUp';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  int get _sendCountForAction {
    if (_peer != null) return _effectiveSendCount;
    return _localChangeEstimate;
  }

  bool get _canSendUpdates {
    if (_busy || !_online || _activeTransfer != null || _isSender) {
      return false;
    }
    if (_peer == null) return false;
    return _sendCountForAction > 0;
  }

  bool get _canRelease =>
      _isSender && _activeTransfer?.isPrepared == true && _online;

  bool _isPackageAlreadyReceived(DeviceTransferMeta transfer) {
    final last = _lastReceive;
    if (last == null) return false;
    return last.sentAt.millisecondsSinceEpoch ==
        transfer.sentAt.millisecondsSinceEpoch;
  }

  DeviceTransferMeta? _effectiveTransfer(DeviceTransferMeta? transfer) {
    if (transfer == null) return null;
    if (_isPackageAlreadyReceived(transfer)) return null;
    return transfer;
  }

  bool get _canReceive {
    final transfer = _activeTransfer;
    if (transfer == null || _isSender || !transfer.isReceivable) return false;
    return !_isPackageAlreadyReceived(transfer);
  }

  bool get _waitingReceiver =>
      _isSender && _activeTransfer?.isPrepared == true && !_receiverReady;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const BrandedProjectName(project: BrandedPageProject.calc),
        backgroundColor: PageShellTheme.appBarBackground,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: EdgeInsets.fromLTRB(
                16,
                16,
                16,
                24 + MediaQuery.paddingOf(context).bottom,
              ),
              children: [
                const Text(
                  'Sincronizza',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Text(
                  'Scambio manuale tra dispositivi: ogni app invia in un colpo '
                  'solo i record che mancano sull\'altro. I dati si integrano '
                  'senza cancellare quelli già presenti.\n\n'
                  'Procedura: apri Sincronizza su entrambi i dispositivi con lo '
                  'stesso account, poi invia da uno e ricevi sull\'altro. Se '
                  'servono scambi in entrambe le direzioni, ripeti un turno '
                  'alla volta.',
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    height: 1.45,
                  ),
                ),
                if (_localState != null) ...[
                  const SizedBox(height: 16),
                  _InfoCard(
                    title: 'Questo dispositivo',
                    rows: [
                      _InfoRow(
                        label: 'Record in archivio',
                        value: '${_localState!.localRecordCount}',
                      ),
                      _InfoRow(
                        label: _sendRowLabel,
                        value: _displaySendCount,
                      ),
                      _InfoRow(
                        label: 'In arrivo dall\'altro',
                        value: _peer == null
                            ? '—'
                            : (_canReceive && _activeTransfer != null
                                ? '${_activeTransfer!.recordCount}'
                                : '$_recordsPeerWouldSend'),
                      ),
                      if (_localState!.lastSyncAtMs > 0)
                        _InfoRow(
                          label: 'Ultimo allineamento',
                          value: DeviceTransferFormat.dateTime(
                            DateTime.fromMillisecondsSinceEpoch(
                              _localState!.lastSyncAtMs,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
                if (_peer != null) ...[
                  const SizedBox(height: 12),
                  _InfoCard(
                    title: 'Altro dispositivo',
                    rows: [
                      _InfoRow(
                        label: 'Record in archivio',
                        value: '${_peer!.localRecordCount}',
                      ),
                      _InfoRow(
                        label: 'Da inviare a te',
                        value: '$_recordsPeerWouldSend',
                      ),
                    ],
                  ),
                ],
                if (!_hasPackageInTransit &&
                    _activeTransfer == null &&
                    _syncHint !=
                        DeviceTransferSyncHint.waitingForPeer) ...[
                  const SizedBox(height: 12),
                  _Banner(
                    color: _syncHint == DeviceTransferSyncHint.aligned
                        ? Colors.green.shade700
                        : const Color(0xFF0A66C2),
                    text: DeviceTransferSyncAdvisor.hintMessage(_syncHint),
                  ),
                ],
                if (!_online) ...[
                  const SizedBox(height: 16),
                  const _Banner(
                    color: Colors.orange,
                    text: 'Connessione richiesta per inviare o ricevere.',
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  _Banner(color: Colors.red.shade700, text: _error!),
                ],
                if (_statusMessage != null) ...[
                  const SizedBox(height: 16),
                  _Banner(color: const Color(0xFF0A66C2), text: _statusMessage!),
                ],
                if (_waitingReceiver) ...[
                  const SizedBox(height: 16),
                  const Center(child: CircularProgressIndicator()),
                  const SizedBox(height: 8),
                  Center(
                    child: Text(
                      'In attesa del secondo dispositivo…',
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                  ),
                ],
                if (_activeTransfer?.isPrepared == true && !_isSender) ...[
                  const SizedBox(height: 16),
                  _Banner(
                    color: Colors.orange.shade800,
                    text:
                        'Pacchetto preparato dal mittente. Attendi che l\'altro '
                        'dispositivo avvii l\'invio, poi tocca «Ricevi dati».',
                  ),
                ],
                if (_lastReceive != null) ...[
                  const SizedBox(height: 16),
                  _InfoCard(
                    title: 'Ultima ricezione',
                    rows: [
                      _InfoRow(
                        label: 'Data invio (mittente)',
                        value: DeviceTransferFormat.dateTime(
                          _lastReceive!.sentAt,
                        ),
                      ),
                      _InfoRow(
                        label: 'Data ricezione',
                        value: DeviceTransferFormat.dateTime(
                          _lastReceive!.receivedAt,
                        ),
                      ),
                      _InfoRow(
                        label: 'Peso totale',
                        value: DeviceTransferFormat.bytes(
                          _lastReceive!.totalBytes,
                        ),
                      ),
                    ],
                  ),
                ],
                if (_canReceive && _activeTransfer != null) ...[
                  const SizedBox(height: 16),
                  _InfoCard(
                    title: 'Pacchetto pronto da ricevere',
                    rows: [
                      _InfoRow(
                        label: 'Tipo',
                        value: _activeTransfer!.isDeltaTransfer
                            ? 'Solo aggiornamenti'
                            : 'Integrazione archivio',
                      ),
                      _InfoRow(
                        label: 'Peso totale',
                        value: DeviceTransferFormat.bytes(
                          _activeTransfer!.totalBytes,
                        ),
                      ),
                      _InfoRow(
                        label: 'Record',
                        value: '${_activeTransfer!.recordCount}',
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 24),
                if (_canSendUpdates)
                  FilledButton.icon(
                    onPressed: _sendUpdatesToPeer,
                    icon: const Icon(Icons.sync_alt),
                    label: Text(
                      'Invia aggiornamenti all\'altro '
                      '($_sendCountForAction)',
                    ),
                  ),
                if (_peer == null &&
                    _online &&
                    _activeTransfer == null &&
                    (_localChangeEstimate > 0 ||
                        (_localState?.localRecordCount ?? 0) > 0)) ...[
                  const SizedBox(height: 12),
                  _Banner(
                    color: Colors.orange.shade800,
                    text:
                        'Apri Sincronizza anche sull\'altro dispositivo con lo '
                        'stesso account: così vedi il conteggio preciso prima '
                        'di inviare.',
                  ),
                ],
                if (_hasPackageInTransit) ...[
                  const SizedBox(height: 16),
                  _Banner(
                    color: const Color(0xFF0A66C2),
                    text:
                        'Pacchetto di $_inTransitRecordCount record inviato. '
                        'Sull\'altro dispositivo tocca «Ricevi dati».\n\n'
                        'Il contatore qui può restare alto finché l\'altro non '
                        'riceve: non serve reinviare.',
                  ),
                ],
                if (_isSender && _activeTransfer?.isPrepared == true) ...[
                  FilledButton.icon(
                    onPressed: _busy || !_online || !_canRelease ? null : _release,
                    icon: const Icon(Icons.upload_outlined),
                    label: const Text('Invia dati ora'),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _receiverReady
                        ? 'Secondo dispositivo rilevato su Sincronizza.'
                        : 'Apri Sincronizza sull\'altro dispositivo prima di '
                            'ricevere, poi tocca «Invia dati ora».',
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ],
                if (!_isSender && _canReceive) ...[
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _busy || !_online ? null : _receive,
                    icon: const Icon(Icons.download_outlined),
                    label: const Text('Ricevi dati'),
                  ),
                ],
                if (_busy) ...[
                  const SizedBox(height: 24),
                  const Center(child: CircularProgressIndicator()),
                ],
              ],
            ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.title, required this.rows});

  final String title;
  final List<_InfoRow> rows;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            for (final row in rows) ...[
              row,
              if (row != rows.last) const SizedBox(height: 8),
            ],
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: Text(
            label,
            style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
          ),
        ),
        Expanded(
          flex: 3,
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.color, required this.text});

  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(text, style: TextStyle(color: color, height: 1.4)),
    );
  }
}
