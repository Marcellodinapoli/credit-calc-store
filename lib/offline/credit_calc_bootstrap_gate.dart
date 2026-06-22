import 'dart:async';

import 'package:credit_calc_core/credit_calc_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../core/maintenance_service.dart';
import '../pages/creditcalc/credit_calc_initial_sync_page.dart';
import '../session/credit_core_session_runtime.dart';
import '../shell/credit_calc_shell.dart';
import '../widgets/maintenance_section_gate.dart';
import 'credit_calc_repository_setup.dart';
import 'credit_calc_runtime.dart';
import 'models/credit_calc_mode.dart';
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
  startupSlow,
  ready,
}

/// Prima sync e sync automatica. La sessione piattaforma è già risolta dal
/// [CreditCoreSessionCoordinator] prima di arrivare qui.
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
  Timer? _startupWatchdog;

  @override
  void initState() {
    super.initState();
    _startupWatchdog = Timer(const Duration(seconds: 18), () {
      if (!mounted || _step != _BootstrapStep.loading) return;
      setState(() => _step = _BootstrapStep.startupSlow);
    });
    _bootstrap();
  }

  @override
  void dispose() {
    _startupWatchdog?.cancel();
    _connectivitySub?.cancel();
    _realtimeSync?.dispose();
    CommissionEntryDataAccess.instance = FirestoreCommissionEntryDataAccess();
    CommissionCreditorDataAccess.instance =
        FirestoreCommissionCreditorDataAccess();
    CreditCalcRepository.clear();
    CreditCalcRuntime.clear();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await _bootstrapCore(user).timeout(const Duration(seconds: 10));
    } on TimeoutException {
      await _bootstrapFastPath(user);
    } catch (_) {
      await _bootstrapFastPath(user);
    }
  }

  void _ensurePlatformSession(String userId) {
    final existing = CreditCoreSessionRuntime.sessionService;
    if (existing != null && existing.userId == userId) return;
    CreditCoreSessionRuntime.sessionService = SessionService(userId: userId);
    CreditCoreSessionRuntime.bootstrapComplete = true;
    CreditCoreSessionRuntime.bootstrapFuture = null;
  }

  Future<void> _bootstrapCore(User user) async {
    await _waitForPlatformSession(user.uid);
    _ensurePlatformSession(user.uid);

    _sessionService = CreditCoreSessionRuntime.sessionService;
    _modePrefs = ModePreferencesService(userId: user.uid);
    _syncEngine = SyncEngine(
      userId: user.uid,
      modePrefs: _modePrefs!,
      sessionService: _sessionService!,
    );

    _connectivitySub ??= ConnectivityService.watchOnline().listen((hasLink) {
      if (!hasLink) {
        _realtimeSync?.stop();
        return;
      }
      unawaited(_whenInternetAvailable());
    });

    await _modePrefs!.ensureOfflineSyncMode();
    await _continueAfterMode();
  }

  Future<void> _bootstrapFastPath(User user) async {
    if (!mounted) return;
    _ensurePlatformSession(user.uid);
    _sessionService ??= CreditCoreSessionRuntime.sessionService;
    _modePrefs ??= ModePreferencesService(userId: user.uid);
    _syncEngine ??= SyncEngine(
      userId: user.uid,
      modePrefs: _modePrefs!,
      sessionService: _sessionService!,
    );
    await _continueAfterMode(skipNetworkChecks: true);
  }

  Future<int> _safeLocalRecordCount() async {
    try {
      return await _syncEngine!
          .localRecordCount()
          .timeout(const Duration(seconds: 4), onTimeout: () => 0);
    } catch (_) {
      return 0;
    }
  }

  Future<void> _waitForPlatformSession(String userId) async {
    const attempts = 20;
    for (var i = 0; i < attempts; i++) {
      final session = CreditCoreSessionRuntime.sessionService;
      if (session != null && session.userId == userId) return;
      await CreditCoreSessionRuntime.waitUntilReady();
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
  }

  void _cancelStartupWatchdog() {
    _startupWatchdog?.cancel();
    _startupWatchdog = null;
  }

  Future<void> _whenInternetAvailable() async {
    if (!await ConnectivityService.isOnline()) return;
    await _syncIfNeeded();
    await _startRealtimeIfNeeded();
  }

  void _ensureRealtimeSync() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _modePrefs == null || _syncEngine == null) return;
    _realtimeSync ??= RealtimeSyncService(
      userId: user.uid,
      modePrefs: _modePrefs!,
      syncEngine: _syncEngine!,
      onDataChanged: _notifyRepositoryDataChanged,
    );
  }

  Future<void> _startRealtimeIfNeeded() async {
    if (_step != _BootstrapStep.ready) return;
    _ensureRealtimeSync();
    await _realtimeSync?.refresh();
  }

  Future<void> _continueAfterMode({bool skipNetworkChecks = false}) async {
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

    var done = await _modePrefs!.isInitialSyncDoneLocally();
    final localCount = await _safeLocalRecordCount();
    final hasLocalCache = done || localCount > 0;

    if (!done && localCount > 0) {
      await _modePrefs!.markInitialSyncComplete(
        recordCount: localCount,
        dataVersion: 'offline-cache',
      );
      done = true;
    }

    if (hasLocalCache) {
      _cancelStartupWatchdog();
    }

    if (!hasLocalCache) {
      if (!mounted) return;
      if (!skipNetworkChecks &&
          !await ConnectivityService.isOnline(
            timeout: const Duration(seconds: 8),
          )) {
        _cancelStartupWatchdog();
        setState(() => _step = _BootstrapStep.offlineSyncRequired);
        return;
      }
      _cancelStartupWatchdog();
      setState(() => _step = _BootstrapStep.initialSync);
      return;
    }
    if (!mounted) return;
    _cancelStartupWatchdog();
    if (!skipNetworkChecks &&
        await ConnectivityService.isOnline(timeout: const Duration(seconds: 4))) {
      try {
        await _syncCatchUpIfNeeded().timeout(const Duration(seconds: 8));
      } catch (_) {}
    }

    if (!mounted) return;
    setState(() => _step = _BootstrapStep.ready);
    unawaited(_startRealtimeIfNeeded());
  }

  Future<void> _continueOfflineIfPossible() async {
    if (_modePrefs == null || _syncEngine == null) {
      await _bootstrapFastPath(FirebaseAuth.instance.currentUser!);
      return;
    }
    await _continueAfterMode(skipNetworkChecks: true);
  }

  Future<void> _startInitialSync() async {
    if (_modePrefs == null || _syncEngine == null) {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      await _bootstrapFastPath(user);
      return;
    }
    if (!mounted) return;
    _cancelStartupWatchdog();
    setState(() => _step = _BootstrapStep.initialSync);
  }

  Future<void> _syncCatchUpIfNeeded() async {
    await _runCatchUpOrRepairSync(
      loadingMessage: 'Aggiornamento copia locale da Firebase…',
    );
  }

  Future<void> _runCatchUpOrRepairSync({
    required String loadingMessage,
  }) async {
    final engine = _syncEngine;
    if (engine == null) return;

    final needsRepair = await engine.needsRepairSync();
    final behind = await engine.isBehindRemote();
    if (!behind && !needsRepair) return;

    if (!mounted) return;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        content: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 20),
            Expanded(
              child: Text(
                needsRepair
                    ? 'Ripristino copia locale da Firebase…'
                    : loadingMessage,
              ),
            ),
          ],
        ),
      ),
    );

    try {
      final result = await engine.catchUpOrRepairIfNeeded();
      if (result?.success == true) {
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
      final result = await _syncEngine?.runSync();
      if (result?.success == true) {
        _notifyRepositoryDataChanged();
      }
    } catch (_) {}
  }

  void _notifyRepositoryDataChanged() =>
      CreditCalcRepositorySetup.notifyDataChanged();

  @override
  Widget build(BuildContext context) {
    switch (_step) {
      case _BootstrapStep.loading:
        return const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        );
      case _BootstrapStep.initialSync:
        return CreditCalcInitialSyncPage(
          syncEngine: _syncEngine!,
          onComplete: () {
            _cancelStartupWatchdog();
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
      case _BootstrapStep.startupSlow:
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
                        'Avvio lento',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'L\'avvio sta impiegando più tempo del previsto. '
                        'Puoi continuare senza attendere o avviare la '
                        'sincronizzazione dati.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 24),
                      FilledButton(
                        onPressed: () {
                          setState(() => _step = _BootstrapStep.loading);
                          _startupWatchdog?.cancel();
                          _startupWatchdog = Timer(const Duration(seconds: 18), () {
                            if (!mounted || _step != _BootstrapStep.loading) {
                              return;
                            }
                            setState(() => _step = _BootstrapStep.startupSlow);
                          });
                          unawaited(_bootstrap());
                        },
                        child: const Text('Riprova avvio'),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: () => unawaited(_continueOfflineIfPossible()),
                        child: const Text('Continua senza attendere'),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton(
                        onPressed: () => unawaited(_startInitialSync()),
                        child: const Text('Avvia sincronizzazione'),
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
