import 'dart:async';

import 'package:credit_calc_core/credit_calc_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../core/maintenance_service.dart';
import '../session/credit_core_session_runtime.dart';
import '../shell/credit_calc_shell.dart';
import '../widgets/maintenance_section_gate.dart';
import 'credit_calc_repository_setup.dart';
import 'credit_calc_runtime.dart';
import 'local_itinerary_coordinator.dart';
import 'repository/credit_calc_repository.dart';
import 'services/local_data_cipher.dart';
import 'services/local_database_service.dart';
import 'services/session_service.dart';

enum _BootstrapStep { loading, startupSlow, ready }

/// Avvio CreditCalc: dati operativi sul dispositivo, senza sync obbligatoria.
class CreditCalcBootstrapGate extends StatefulWidget {
  const CreditCalcBootstrapGate({super.key});

  @override
  State<CreditCalcBootstrapGate> createState() =>
      _CreditCalcBootstrapGateState();
}

class _CreditCalcBootstrapGateState extends State<CreditCalcBootstrapGate> {
  _BootstrapStep _step = _BootstrapStep.loading;
  SessionService? _sessionService;
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
    CommissionEntryDataAccess.instance = FirestoreCommissionEntryDataAccess();
    CommissionCreditorDataAccess.instance =
        FirestoreCommissionCreditorDataAccess();
    CommissionEntriesDataAccess.instance =
        FirestoreCommissionEntriesDataAccess();
    CreditorsListDataAccess.instance = FirestoreCreditorsListDataAccess();
    CreditCalcRepositorySetup.clear();
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
      await _continueAfterLogin(user.uid);
    } catch (_) {
      await _continueAfterLogin(user.uid);
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
    await _continueAfterLogin(user.uid);
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

  Future<void> _continueAfterLogin(String userId) async {
    _sessionService ??= CreditCoreSessionRuntime.sessionService;

    PublicPlanLimitsConfigService.start();
    await PublicPlanLimitsConfigService.ensureLoaded();

    // Dati operativi solo su questo dispositivo (PC ≠ telefono).
    try {
      await LocalDatabaseService.instance.database;
    } catch (e, st) {
      debugPrint('CreditCalcBootstrapGate: database locale non disponibile: $e\n$st');
    }

    LocalDataCipher.configureBackup(
      read: () => LocalDatabaseService.instance.getMeta('local_cipher_key_v1'),
      write: (value) =>
          LocalDatabaseService.instance.setMeta('local_cipher_key_v1', value),
      readHistory: () =>
          LocalDatabaseService.instance.getMeta('local_cipher_key_history_v1'),
      writeHistory: (value) => LocalDatabaseService.instance
          .setMeta('local_cipher_key_history_v1', value),
    );

    await LocalDataCipher.warmUp();

    CreditCalcRepositorySetup.apply(userId: userId);
    CreditCalcRuntime.install(sessionService: _sessionService!);
    CreditCalcRepositorySetup.notifyDataChanged();

    await LocalItineraryCoordinator.start(userId);

    if (!mounted) return;
    _cancelStartupWatchdog();
    setState(() => _step = _BootstrapStep.ready);
  }

  @override
  Widget build(BuildContext context) {
    switch (_step) {
      case _BootstrapStep.loading:
        return const Scaffold(
          body: Center(child: CircularProgressIndicator()),
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
                        'Puoi continuare senza attendere.',
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
                          _startupWatchdog = Timer(
                            const Duration(seconds: 18),
                            () {
                              if (!mounted ||
                                  _step != _BootstrapStep.loading) {
                                return;
                              }
                              setState(() => _step = _BootstrapStep.startupSlow);
                            },
                          );
                          unawaited(_bootstrap());
                        },
                        child: const Text('Riprova avvio'),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: () {
                          final uid = FirebaseAuth.instance.currentUser?.uid;
                          if (uid != null) {
                            unawaited(_continueAfterLogin(uid));
                          }
                        },
                        child: const Text('Continua senza attendere'),
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
