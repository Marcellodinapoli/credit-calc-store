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

class _DeviceSyncPageState extends State<DeviceSyncPage> {
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
  StreamSubscription<bool>? _receiverSub;
  StreamSubscription<DeviceTransferPeerState?>? _peerSub;
  Timer? _presenceTimer;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    _receiverSub?.cancel();
    _peerSub?.cancel();
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
          transfer = await DeviceTransferService.readTransferMeta(uid);
          if (transfer?.isPrepared == true) {
            isSender = await DeviceTransferService.isActiveSender(uid);
          }
        } catch (_) {}
      }
    }

    final syncHint = localState == null
        ? DeviceTransferSyncHint.waitingForPeer
        : DeviceTransferSyncAdvisor.advise(local: localState, peer: peer);

    if (!mounted) return;
    setState(() {
      _online = online;
      _activeTransfer = transfer;
      _localState = localState;
      _peer = peer;
      _isSender = isSender;
      _syncHint = syncHint;
      _loading = false;
    });

    await _syncPresenceAndWatch(uid, isSender);
  }

  Future<void> _syncPresenceAndWatch(String? uid, bool isSender) async {
    await _receiverSub?.cancel();
    await _peerSub?.cancel();
    _presenceTimer?.cancel();
    _receiverSub = null;
    _peerSub = null;
    _presenceTimer = null;

    if (uid == null || !_online) return;

    await DeviceTransferService.pingReceiverPresence(uid);
    _presenceTimer = Timer.periodic(
      const Duration(seconds: DeviceTransferConfig.presenceHeartbeatSeconds),
      (_) => DeviceTransferService.pingReceiverPresence(uid),
    );

    _peerSub = DeviceTransferService.watchPeerState(uid).listen((peer) {
      if (!mounted) return;
      final local = _localState;
      setState(() {
        _peer = peer;
        if (local != null) {
          _syncHint = DeviceTransferSyncAdvisor.advise(local: local, peer: peer);
        }
      });
    });

    if (isSender) {
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
  }

  Future<void> _prepare() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    setState(() {
      _busy = true;
      _error = null;
      _statusMessage = 'Cifratura e preparazione pacchetto…';
      _lastReceive = null;
      _receiverReady = false;
    });

    try {
      final result = await DeviceTransferService.preparePackage(uid);
      if (!mounted) return;
      setState(() {
        final kind = result.isDelta ? 'aggiornamenti' : 'archivio completo';
        _statusMessage =
            'Pacchetto pronto ($kind: ${result.recordCount} record, '
            '${DeviceTransferFormat.bytes(result.totalBytes)}).\n\n'
            'Ora apri l\'altra app, accedi con lo stesso account '
            'e apri la pagina «Sincronizza» dal menu ⋮.\n\n'
            'Attendo il secondo dispositivo…';
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
        _statusMessage =
            'Trasferimento completato: ${result.importedRecords} record '
            '(${DeviceTransferFormat.bytes(result.totalBytes)}) importati.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        await _refresh();
      }
    }
  }

  bool get _canPrepare {
    if (_busy || !_online || _activeTransfer != null || _isSender) {
      return false;
    }
    return _syncHint == DeviceTransferSyncHint.youShouldSend ||
        _syncHint == DeviceTransferSyncHint.peerEmptyNeedsFull ||
        _syncHint == DeviceTransferSyncHint.bothHaveChanges;
  }

  bool get _canRelease =>
      _isSender && _activeTransfer?.isPrepared == true && _receiverReady;

  bool get _canReceive => _activeTransfer?.isReceivable == true && !_isSender;

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
                  'Ogni dispositivo condivide i propri dati: l\'altro li integra '
                  'senza cancellare i suoi. Ripeti da entrambi per tenere tutto '
                  'aggiornato.',
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    height: 1.45,
                  ),
                ),
                if (_localState != null && _activeTransfer == null) ...[
                  const SizedBox(height: 16),
                  _InfoCard(
                    title: 'Questo dispositivo',
                    rows: [
                      _InfoRow(
                        label: 'Record in archivio',
                        value: '${_localState!.localRecordCount}',
                      ),
                      _InfoRow(
                        label: 'Da condividere',
                        value: '${_localState!.pendingChangeCount}',
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
                if (_peer != null && _activeTransfer == null) ...[
                  const SizedBox(height: 12),
                  _InfoCard(
                    title: 'Altro dispositivo',
                    rows: [
                      _InfoRow(
                        label: 'Record in archivio',
                        value: '${_peer!.localRecordCount}',
                      ),
                      _InfoRow(
                        label: 'Da condividere',
                        value: '${_peer!.pendingChangeCount}',
                      ),
                    ],
                  ),
                ],
                if (_activeTransfer == null &&
                    _syncHint != DeviceTransferSyncHint.waitingForPeer) ...[
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
                if (_canPrepare)
                  FilledButton.icon(
                    onPressed: _prepare,
                    icon: const Icon(Icons.lock_outline),
                    label: const Text('Prepara pacchetto da trasferire'),
                  ),
                if (_isSender && _activeTransfer?.isPrepared == true) ...[
                  FilledButton.icon(
                    onPressed: _busy || !_online || !_canRelease ? null : _release,
                    icon: const Icon(Icons.upload_outlined),
                    label: const Text('Invia dati ora'),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _receiverReady
                        ? 'Secondo dispositivo rilevato.'
                        : 'Il pulsante si attiva quando l\'altra app è aperta '
                            'su Sincronizza con lo stesso account.',
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ],
                if (!_isSender) ...[
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _busy || !_online || !_canReceive ? null : _receive,
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
