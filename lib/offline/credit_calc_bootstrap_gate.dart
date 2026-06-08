import 'dart:async';

import 'package:credit_calc_core/credit_calc_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../pages/creditcalc/credit_calc_initial_sync_page.dart';
import '../shell/credit_calc_shell.dart';
import '../widgets/maintenance_section_gate.dart';
import '../widgets/session_takeover_dialog.dart';
import '../core/maintenance_service.dart';
import 'models/credit_calc_mode.dart';
import 'credit_calc_runtime.dart';
import 'credit_calc_repository_setup.dart';
import 'repository/credit_calc_repository.dart';
import 'services/connectivity_service.dart';
import 'services/mode_preferences_service.dart';
import 'services/realtime_sync_service.dart';
import 'services/session_service.dart';
import 'services/sync_engine.dart';

enum _BootstrapStep {
  loading,
  initialSync,
  offlineSyncRequired,
  ready,
}

/// Gestisce prima sync, sessione unica e sync automatica (sempre offline + sync).
class CreditCalcBootstrapGate extends StatefulWidget {
  const CreditCalcBootstrapGate({super.key});

  @override
  State<CreditCalcBootstrapGate> createState() =>
      _CreditCalcBootstrapGateState();
}

class _CreditCalcBootstrapGateState extends State<CreditCalcBootstrapGate> {
  _BootstrapStep _step = _BootstrapStep.loading;
  ModePreferencesService? _modePrefs;
  SessionService? _sessionService;
  SyncEngine? _syncEngine;
  RealtimeSyncService? _realtimeSync;
  StreamSubscription<bool>? _connectivitySub;
  Timer? _heartbeat;
  String? _sessionRevokedMessage;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    _heartbeat?.cancel();
    _realtimeSync?.dispose();
    _sessionService?.dispose();
    CommissionEntryDataAccess.instance = FirestoreCommissionEntryDataAccess();
    CommissionCreditorDataAccess.instance =
        FirestoreCommissionCreditorDataAccess();
    unawaited(_sessionService?.releaseSession());
    CreditCalcRepository.clear();
    CreditCalcRuntime.clear();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      _modePrefs = ModePreferencesService(userId: user.uid);
      _sessionService = SessionService(userId: user.uid);
      _syncEngine = SyncEngine(
        userId: user.uid,
        modePrefs: _modePrefs!,
        sessionService: _sessionService!,
      );

      await _setupSession(online: await ConnectivityService.isOnline());

      await _modePrefs!.ensureOfflineSyncMode();

      await _continueAfterMode();
    } catch (_) {
      if (!mounted) return;
      final done = await _modePrefs?.isInitialSyncDoneLocally() ?? false;
      if (done) {
        await _continueAfterMode();
      } else {
        setState(() => _step = _BootstrapStep.offlineSyncRequired);
      }
    }
  }

  Future<void> _setupSession({required bool online}) async {
    _connectivitySub = ConnectivityService.watchOnline().listen((hasLink) {
      if (!hasLink) {
        _realtimeSync?.stop();
        return;
      }
      unawaited(_whenInternetAvailable());
    });

    if (!online) {
      await _sessionService!.claimSession();
      return;
    }

    await _claimRemoteSessionWhenOnline();
  }

  Future<void> _whenInternetAvailable() async {
    if (!await ConnectivityService.isOnline()) return;
    await _claimRemoteSessionWhenOnline();
    await _syncIfNeeded();
    await _startRealtimeIfNeeded();
  }

  Future<void> _claimRemoteSessionWhenOnline() async {
    final session = _sessionService;
    if (session == null || !await ConnectivityService.isOnline()) return;

    var tookOver = false;
    try {
      final conflict = await session.findConflictingSession();
      if (!mounted) return;
      if (conflict != null) {
        final proceed = await showSessionTakeoverDialog(context, conflict);
        if (!proceed || !mounted) {
          await FirebaseAuth.instance.signOut();
          return;
        }
        tookOver = true;
      }
      await session.claimSession(refreshSessionId: true);
      session.startWatching(onSessionRevoked: _onSessionRevoked);
      _heartbeat ??= Timer.periodic(
        const Duration(seconds: 60),
        (_) => _sessionService?.touchActivity(),
      );
      if (tookOver) {
        await _syncAfterHandoff();
      }
    } catch (_) {
      await session.ensureLocalSession();
    }
  }

  Future<void> _syncAfterHandoff() async {
    if (!mounted) return;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 20),
            Expanded(
              child: Text('Sincronizzazione dati in corso…'),
            ),
          ],
        ),
      ),
    );
    try {
      final result = await _syncEngine?.runSync();
      if (result?.success == true) {
        _notifyRepositoryDataChanged();
      }
    } catch (_) {}
    if (mounted) Navigator.of(context, rootNavigator: true).pop();
  }

  void _ensureRealtimeSync() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _modePrefs == null || _syncEngine == null) return;
    _realtimeSync ??= RealtimeSyncService(
      userId: user.uid,
      modePrefs: _modePrefs!,
      sessionService: _sessionService!,
      syncEngine: _syncEngine!,
      onDataChanged: _notifyRepositoryDataChanged,
    );
  }

  Future<void> _startRealtimeIfNeeded() async {
    if (_step != _BootstrapStep.ready) return;
    _ensureRealtimeSync();
    await _realtimeSync?.refresh();
  }

  void _onSessionRevoked() {
    if (!mounted) return;
    _realtimeSync?.stop();
    setState(() {
      _sessionRevokedMessage =
          'La sessione è stata aperta su un altro dispositivo.';
    });
    unawaited(FirebaseAuth.instance.signOut());
  }

  Future<void> _continueAfterMode() async {
    const mode = CreditCalcMode.offlineSync;

    CreditCalcRepositorySetup.apply(
      mode: mode,
      userId: FirebaseAuth.instance.currentUser!.uid,
      modePrefs: _modePrefs!,
      sessionService: _sessionService!,
      syncEngine: _syncEngine!,
    );
    _ensureRealtimeSync();
    CreditCalcRuntime.install(
      modePrefs: _modePrefs!,
      sessionService: _sessionService!,
      syncEngine: _syncEngine!,
      realtimeSync: _realtimeSync,
    );

    final done = await _modePrefs!.isInitialSyncDoneLocally();
    if (!done) {
      if (!mounted) return;
      if (!await ConnectivityService.isOnline()) {
        setState(() => _step = _BootstrapStep.offlineSyncRequired);
        return;
      }
      setState(() => _step = _BootstrapStep.initialSync);
      return;
    }
    if (!mounted) return;
    if (await ConnectivityService.isOnline()) {
      await _syncCatchUpIfNeeded();
    }

    if (!mounted) return;
    setState(() => _step = _BootstrapStep.ready);
    unawaited(_startRealtimeIfNeeded());
  }

  Future<void> _syncCatchUpIfNeeded() async {
    final engine = _syncEngine;
    if (engine == null) return;
    await _sessionService?.ensureLocalSession();
    if (!await engine.isBehindRemote()) return;

    if (!mounted) return;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 20),
            Expanded(
              child: Text('Aggiornamento copia locale da Firebase…'),
            ),
          ],
        ),
      ),
    );

    try {
      final result = await engine.runSync();
      if (result.success) {
        _notifyRepositoryDataChanged();
      }
    } catch (_) {}

    if (mounted) Navigator.of(context, rootNavigator: true).pop();
  }

  Future<void> _syncIfNeeded() async {
    if (_step != _BootstrapStep.ready && _step != _BootstrapStep.loading) {
      return;
    }
    try {
      await _sessionService?.ensureLocalSession();
      final result = await _syncEngine?.runSync();
      if (result?.success == true) {
        _notifyRepositoryDataChanged();
      }
    } catch (_) {}
  }

  void _notifyRepositoryDataChanged() => CreditCalcRepositorySetup.notifyDataChanged();

  @override
  Widget build(BuildContext context) {
    if (_sessionRevokedMessage != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              _sessionRevokedMessage!,
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    switch (_step) {
      case _BootstrapStep.loading:
        return const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        );
      case _BootstrapStep.initialSync:
        return CreditCalcInitialSyncPage(
          syncEngine: _syncEngine!,
          onComplete: () {
            _notifyRepositoryDataChanged();
            setState(() => _step = _BootstrapStep.ready);
            unawaited(_syncIfNeeded());
            unawaited(_startRealtimeIfNeeded());
          },
        );
      case _BootstrapStep.offlineSyncRequired:
        return Scaffold(
          backgroundColor: const Color(0xFFE8E8E8),
          body: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Connessione richiesta',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'La prima sincronizzazione dei dati CreditCalc richiede '
                        'internet. Attiva la rete e riprova.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 24),
                      FilledButton(
                        onPressed: () async {
                          if (!await ConnectivityService.isOnline()) return;
                          if (!mounted) return;
                          setState(() => _step = _BootstrapStep.initialSync);
                        },
                        child: const Text('Riprova'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      case _BootstrapStep.ready:
        return const MaintenanceSectionGate(
          sectionName: MaintenanceService.creditCalc,
          fullScreen: true,
          child: CreditCalcShell(),
        );
    }
  }
}
