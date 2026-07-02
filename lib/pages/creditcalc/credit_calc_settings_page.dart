import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../offline/device_transfer/device_transfer_models.dart';
import '../../offline/device_transfer/device_transfer_service.dart';
import '../../offline/services/session_service.dart';
import '../../ui/layout/page_shell.dart';

class CreditCalcSettingsPage extends StatefulWidget {
  final SessionService sessionService;

  const CreditCalcSettingsPage({
    super.key,
    required this.sessionService,
  });

  @override
  State<CreditCalcSettingsPage> createState() => _CreditCalcSettingsPageState();
}

class _CreditCalcSettingsPageState extends State<CreditCalcSettingsPage> {
  bool _loading = true;
  DeviceTransferLocalHistory? _history;
  DeviceTransferMeta? _pending;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);

    final uid = FirebaseAuth.instance.currentUser?.uid;
    DeviceTransferLocalHistory? history;
    DeviceTransferMeta? pending;
    if (uid != null) {
      try {
        history = await DeviceTransferService.readLocalHistory(uid);
        pending = await DeviceTransferService.readPendingMeta(uid);
      } catch (_) {}
    }

    if (!mounted) return;
    setState(() {
      _history = history;
      _pending = pending;
      _loading = false;
    });
  }

  bool get _hasSummary {
    final history = _history;
    return _pending != null ||
        history?.lastSendAt != null ||
        history?.lastReceiveAt != null;
  }

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
                  'Storico trasferimenti',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Riepilogo trasferimenti dati su questo dispositivo.',
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    height: 1.45,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 16),
                if (!_hasSummary)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'Nessun trasferimento registrato su questo dispositivo.',
                        style: TextStyle(color: Colors.grey.shade700),
                      ),
                    ),
                  ),
                if (_history?.lastSendAt != null) ...[
                  _SummaryCard(
                    title: 'Ultimo invio',
                    rows: [
                      _SummaryRow(
                        label: 'Data invio',
                        value: DeviceTransferFormat.dateTime(
                          _history!.lastSendAt!,
                        ),
                      ),
                      if (_history!.lastSendBytes != null)
                        _SummaryRow(
                          label: 'Peso totale',
                          value: DeviceTransferFormat.bytes(
                            _history!.lastSendBytes!,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
                if (_history?.lastReceiveAt != null) ...[
                  _SummaryCard(
                    title: 'Ultima ricezione',
                    rows: [
                      if (_history!.lastReceiveSentAt != null)
                        _SummaryRow(
                          label: 'Data invio (mittente)',
                          value: DeviceTransferFormat.dateTime(
                            _history!.lastReceiveSentAt!,
                          ),
                        ),
                      _SummaryRow(
                        label: 'Data ricezione',
                        value: DeviceTransferFormat.dateTime(
                          _history!.lastReceiveAt!,
                        ),
                      ),
                      if (_history!.lastReceiveBytes != null)
                        _SummaryRow(
                          label: 'Peso totale',
                          value: DeviceTransferFormat.bytes(
                            _history!.lastReceiveBytes!,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
                if (_pending != null) ...[
                  _SummaryCard(
                    title: 'Pacchetto in attesa di ricezione',
                    rows: [
                      _SummaryRow(
                        label: 'Data invio',
                        value: DeviceTransferFormat.dateTime(_pending!.sentAt),
                      ),
                      if (_pending!.totalBytes > 0)
                        _SummaryRow(
                          label: 'Peso totale',
                          value: DeviceTransferFormat.bytes(_pending!.totalBytes),
                        ),
                      _SummaryRow(
                        label: 'Record',
                        value: '${_pending!.recordCount}',
                      ),
                      _SummaryRow(
                        label: 'Scadenza',
                        value: DeviceTransferFormat.dateTime(
                          DateTime.fromMillisecondsSinceEpoch(
                            _pending!.expiresAtMs,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
                const SizedBox(height: 8),
                Text(
                  'Per inviare o ricevere dati apri il menu ⋮ e seleziona '
                  '«Sincronizza».',
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    height: 1.45,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 24),
                FutureBuilder<PackageInfo>(
                  future: PackageInfo.fromPlatform(),
                  builder: (context, snap) {
                    final version = snap.data?.version ?? '…';
                    final build = snap.data?.buildNumber;
                    final label = build == null || build.isEmpty
                        ? 'v$version'
                        : 'v$version ($build)';
                    return Center(
                      child: Text(
                        'Versione installata: $label',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.title, required this.rows});

  final String title;
  final List<_SummaryRow> rows;

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

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value});

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
