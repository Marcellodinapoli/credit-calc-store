import 'package:credit_calc_core/credit_calc_core.dart';

import 'package:firebase_auth/firebase_auth.dart';

import 'package:flutter/material.dart';



import '../../ui/layout/page_shell.dart';



import '../../offline/credit_calc_repository_setup.dart';

import '../../offline/models/credit_calc_mode.dart';

import '../../offline/repository/credit_calc_repository.dart';

import '../../offline/services/connectivity_service.dart';

import '../../offline/services/mode_preferences_service.dart';

import '../../offline/services/session_service.dart';

import '../../offline/credit_calc_runtime.dart';
import '../../offline/services/device_identity_service.dart';

import '../../offline/services/sync_engine.dart';




class CreditCalcSettingsPage extends StatefulWidget {

  final ModePreferencesService modePrefs;

  final SessionService sessionService;

  final SyncEngine syncEngine;



  const CreditCalcSettingsPage({

    super.key,

    required this.modePrefs,

    required this.sessionService,

    required this.syncEngine,

  });



  @override

  State<CreditCalcSettingsPage> createState() => _CreditCalcSettingsPageState();

}



class _CreditCalcSettingsPageState extends State<CreditCalcSettingsPage> {

  DateTime? _lastSync;

  int _localCount = 0;

  int _pendingCount = 0;

  int? _remoteCreditors;

  int? _remoteCalculations;

  String? _activeDevice;

  String? _activeDeviceType;

  String? _localDeviceLabel;

  bool _holdsSession = true;

  bool _online = true;

  bool _loading = true;

  bool _syncing = false;



  @override

  void initState() {

    super.initState();

    _refresh();

  }



  void _ensureRepository() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      if (CreditCalcRepository.instance.mode != CreditCalcMode.offlineSync) {
        CreditCalcRepositorySetup.apply(
          mode: CreditCalcMode.offlineSync,
          userId: user.uid,
          modePrefs: widget.modePrefs,
          sessionService: widget.sessionService,
          syncEngine: widget.syncEngine,
        );
      }
    } catch (_) {
      CreditCalcRepositorySetup.apply(
        mode: CreditCalcMode.offlineSync,
        userId: user.uid,
        modePrefs: widget.modePrefs,
        sessionService: widget.sessionService,
        syncEngine: widget.syncEngine,
      );
    }
  }



  Future<void> _refresh() async {

    setState(() => _loading = true);

    await widget.modePrefs.ensureOfflineSyncMode();
    _ensureRepository();

    final last = await widget.modePrefs.lastSyncAt();

    final session = await widget.sessionService.currentSession();

    final holds = await widget.sessionService.holdsActiveSession();

    final localProfile = await DeviceIdentityService.deviceProfile();

    final online = await ConnectivityService.isOnline();

    var localCount = 0;

    var pending = 0;

    int? remoteCreditors;

    int? remoteCalculations;



    try {

      localCount = await CreditCalcRepository.instance.localRecordCount();

      pending = await CreditCalcRepository.instance.pendingCount();

    } catch (_) {}



    if (online) {

      try {

        final remote = await widget.syncEngine.probeRemoteCounts();

        remoteCreditors = remote.creditors;

        remoteCalculations = remote.calculations;

      } catch (_) {}

    }



    if (!mounted) return;

    setState(() {

      _lastSync = last;

      _activeDevice = session?.active == true ? session?.deviceLabel : null;

      _activeDeviceType = session?.active == true ? session?.deviceType : null;

      _localDeviceLabel = localProfile.label;

      _holdsSession = holds;

      _online = online;

      _localCount = localCount;

      _pendingCount = pending;

      _remoteCreditors = remoteCreditors;

      _remoteCalculations = remoteCalculations;

      _loading = false;

    });

  }



  Future<void> _runSync(Future<SyncRunResult> Function() action) async {
    await widget.modePrefs.ensureOfflineSyncMode();
    _ensureRepository();
    setState(() => _syncing = true);

    final result = await action();

    if (result.success) {

      CreditCalcRepositorySetup.notifyDataChanged();

    }

    await CreditCalcRuntime.refreshPendingSyncCount();
    await _refresh();

    if (!mounted) return;

    setState(() => _syncing = false);

    ScaffoldMessenger.of(context).showSnackBar(

      SnackBar(

        content: Text(

          result.success

              ? (result.message ?? 'Sincronizzazione completata.')

              : (result.message ?? 'Sincronizzazione non riuscita.'),

        ),

        duration: Duration(seconds: result.success ? 5 : 8),

      ),

    );

  }



  Future<void> _manualSync() => _runSync(widget.syncEngine.runSync);



  Future<void> _repairSync() async {

    final ok = await showDialog<bool>(

      context: context,

      builder: (ctx) => AlertDialog(

        title: const Text('Ripara sincronizzazione'),

        content: const Text(

          'Cancella i dati locali di questo account e li riscarica da Firebase. '

          'Le modifiche non ancora inviate andranno perse.',

        ),

        actions: [

          TextButton(

            onPressed: () => Navigator.pop(ctx, false),

            child: const Text('Annulla'),

          ),

          FilledButton(

            onPressed: () => Navigator.pop(ctx, true),

            child: const Text('Ripara'),

          ),

        ],

      ),

    );

    if (ok != true) return;

    await _runSync(widget.syncEngine.repairSync);

  }



  String _formatDate(DateTime? dt) {

    if (dt == null) return 'Mai';

    return '${dt.day.toString().padLeft(2, '0')}/'

        '${dt.month.toString().padLeft(2, '0')}/'

        '${dt.year} '

        '${dt.hour.toString().padLeft(2, '0')}:'

        '${dt.minute.toString().padLeft(2, '0')}';

  }



  @override

  Widget build(BuildContext context) {

    final busy = _loading || _syncing;

    return Scaffold(

      appBar: AppBar(

        title: const Text('Impostazioni CreditCalc'),

        backgroundColor: PageShellTheme.appBarBackground,

      ),

      body: busy

          ? const Center(child: CircularProgressIndicator())

          : ListView(

              padding: EdgeInsets.fromLTRB(
                16,
                16,
                16,
                24 + MediaQuery.paddingOf(context).bottom,
              ),

              children: [

                _InfoTile(

                  label: 'Connessione',

                  value: _online ? 'Online' : 'Offline',

                ),

                _InfoTile(

                  label: 'Ultima sincronizzazione',

                  value: _formatDate(_lastSync),

                ),

                _InfoTile(

                  label: 'Su Firebase (questo account)',

                  value: _remoteCreditors == null

                      ? '—'

                      : '$_remoteCreditors creditori, '

                          '$_remoteCalculations pratiche',

                ),

                _InfoTile(

                  label: 'Copia locale (creditori + pratiche)',

                  value: '$_localCount',

                ),

                _InfoTile(

                  label: 'Modifiche in attesa di internet',

                  value: '$_pendingCount',

                  highlight: _pendingCount > 0,

                ),

                _InfoTile(

                  label: 'Questo dispositivo',

                  value: _localDeviceLabel ?? '—',

                ),

                _InfoTile(

                  label: 'Sessione CreditCalc',

                  value: _holdsSession
                      ? 'Attiva su questo dispositivo'
                      : (_activeDevice == null
                          ? 'Altro dispositivo'
                          : 'Su $_activeDevice ($_activeDeviceType)'),

                ),

                Padding(
                  padding: const EdgeInsets.only(top: 6, bottom: 8),
                  child: Text(
                    'Un solo dispositivo alla volta. Per cambiare dispositivo '
                    'apri CreditCalc altrove e scegli «Continua qui».',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                      height: 1.35,
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                FilledButton.icon(

                  onPressed: _manualSync,

                  icon: const Icon(Icons.sync),

                  label: const Text('Sincronizza ora'),

                  style: FilledButton.styleFrom(

                    backgroundColor: ProjectColors.calc,

                  ),

                ),

                const SizedBox(height: 12),

                OutlinedButton.icon(

                  onPressed: _repairSync,

                  icon: const Icon(Icons.build_circle_outlined),

                  label: const Text('Ripara sincronizzazione'),

                ),

                Padding(

                  padding: const EdgeInsets.only(top: 6, bottom: 4),

                  child: Text(

                    'Cancella i dati locali e li riscarica da Firebase. '

                    'Usalo se i numeri non tornano.',

                    style: TextStyle(

                      fontSize: 12,

                      color: Colors.grey.shade600,

                      height: 1.35,

                    ),

                  ),

                ),

              ],

            ),

    );

  }

}



class _InfoTile extends StatelessWidget {

  final String label;

  final String value;

  final bool highlight;



  const _InfoTile({
    required this.label,
    required this.value,
    this.highlight = false,
  });



  @override

  Widget build(BuildContext context) {

    final accent = Colors.red.shade700;
    return Card(
      color: highlight ? Colors.red.shade50 : null,
      shape: highlight
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: accent, width: 1.5),
            )
          : null,
      child: ListTile(
        title: Text(
          label,
          style: highlight
              ? TextStyle(color: accent, fontWeight: FontWeight.w600)
              : null,
        ),
        subtitle: Text(
          value,
          style: highlight
              ? TextStyle(
                  color: accent,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                )
              : null,
        ),
      ),
    );

  }

}


