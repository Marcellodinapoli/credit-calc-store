import 'dart:async';

import 'package:credit_calc_core/credit_calc_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../core/maintenance_service.dart';
import '../session/credit_core_session_runtime.dart';
import '../session/app_session_gate.dart';
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
  StreamSubscription<AppSessionRole>? _sessionRoleSub;
  Future<void>? _operationalDataInit;

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
    _sessionRoleSub?.cancel();
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

  Future<void> _bootstrapCore(User user) async {
    await _waitForPlatformSession(user.uid);
    _sessionService = CreditCoreSessionRuntime.sessionService;
    if (_sessionService?.role == AppSessionRole.secondaryBlocked) {
      _finishReady();
      return;
    }
    await _continueAfterLogin(user.uid);
  }

  Future<void> _waitForPlatformSession(String userId) async {
    const attempts = 40;
    for (var i = 0; i < attempts; i++) {
      if (CreditCoreSessionRuntime.isSessionReady &&
          CreditCoreSessionRuntime.sessionService?.userId == userId) {
        return;
      }
      await CreditCoreSessionRuntime.waitUntilReady();
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
  }

  void _finishReady() {
    if (!mounted) return;
    _cancelStartupWatchdog();
    setState(() => _step = _BootstrapStep.ready);
    _attachSessionRoleListener();
    unawaited(_ensureOperationalData());
  }

  void _attachSessionRoleListener() {
    _sessionRoleSub?.cancel();
    final session = CreditCoreSessionRuntime.sessionService;
    if (session == null) return;

    _sessionRoleSub = session.roleStream.listen((role) {
      if (role == AppSessionRole.primary) {
        unawaited(_ensureOperationalData());
      }
    });
  }

  bool _isOperationalDataReady() {
    try {
      CreditCalcRepository.instance;
      return CreditCalcRuntime.isReady;
    } catch (_) {
      return false;
    }
  }

  Future<void> _ensureOperationalData() {
    if (_operationalDataInit != null) return _operationalDataInit!;

    final future = _ensureOperationalDataImpl();
    _operationalDataInit = future;
    return future.whenComplete(() {
      if (identical(_operationalDataInit, future)) {
        _operationalDataInit = null;
      }
    });
  }

  Future<void> _ensureOperationalDataImpl() async {
    if (_isOperationalDataReady()) return;

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final session = CreditCoreSessionRuntime.sessionService;
    if (session?.role != AppSessionRole.primary) return;

    await _continueAfterLogin(uid);
    if (mounted) setState(() {});
  }

  void _cancelStartupWatchdog() {
    _startupWatchdog?.cancel();
    _startupWatchdog = null;
  }

  Future<void> _continueAfterLogin(String userId) async {
    _sessionService ??= CreditCoreSessionRuntime.sessionService;
    if (_sessionService?.role == AppSessionRole.secondaryBlocked) {
      _finishReady();
      return;
    }

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

    _finishReady();
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
        return MaintenanceSectionGate(
          sectionName: MaintenanceService.creditCalc,
          fullScreen: true,
          child: AppSessionGate(
            key: ValueKey(FirebaseAuth.instance.currentUser?.uid ?? 'guest'),
            child: _OperationalDataReadyGate(
              isReady: _isOperationalDataReady(),
              child: const CreditCalcShell(),
            ),
          ),
        );
    }
  }
}

class _OperationalDataReadyGate extends StatelessWidget {
  const _OperationalDataReadyGate({
    required this.isReady,
    required this.child,
  });

  final bool isReady;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (isReady) return child;
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
