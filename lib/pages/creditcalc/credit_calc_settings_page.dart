import 'package:flutter/material.dart';

import '../../offline/repository/credit_calc_repository.dart';
import '../../offline/services/connectivity_service.dart';
import '../../offline/services/device_identity_service.dart';
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
  int _localCount = 0;
  String? _localDeviceLabel;
  bool _online = true;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);

    final localProfile = await DeviceIdentityService.deviceProfile();
    final online = await ConnectivityService.isOnline();

    var localCount = 0;
    try {
      localCount = await CreditCalcRepository.instance.localRecordCount();
    } catch (_) {}

    if (!mounted) return;
    setState(() {
      _localDeviceLabel = localProfile.label;
      _online = online;
      _localCount = localCount;
      _loading = false;
    });
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
                  'Impostazioni',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                _InfoTile(
                  label: 'Connessione',
                  value: _online ? 'Online' : 'Offline',
                ),
                _InfoTile(
                  label: 'Dati su questo dispositivo',
                  value: '$_localCount record (creditori + pratiche)',
                ),
                _InfoTile(
                  label: 'Questo dispositivo',
                  value: _localDeviceLabel ?? '—',
                ),
                const SizedBox(height: 8),
                Text(
                  'Creditori, provvigioni e itinerario sono salvati sul '
                  'telefono. Formazione e area personale richiedono '
                  'connessione quando necessario.',
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    height: 1.45,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(label),
        subtitle: Text(value),
      ),
    );
  }
}
