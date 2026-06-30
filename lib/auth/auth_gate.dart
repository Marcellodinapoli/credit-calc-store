import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:credit_calc_core/credit_calc_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'biometric_lock_gate.dart';
import 'public_home_page.dart';
import 'registration_consents_service.dart';
import 'waiting_page.dart';
import '../core/maintenance_service.dart';
import '../offline/credit_calc_bootstrap_gate.dart';
import '../offline/credit_calc_runtime.dart';
import '../services/desktop_push_service.dart';
import '../services/fcm_service.dart';
import '../session/credit_core_session_coordinator.dart';
import '../session/credit_core_session_runtime.dart';

/// Router principale post-Firebase Auth (login / app autenticata).
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  StreamSubscription<User?>? _authSub;
  final bool _sessionAtLaunch = FirebaseAuth.instance.currentUser != null;

  static Future<void> _onBiometricUnlocked() async {
    await CreditCoreSessionRuntime.waitUntilReady();
    await CreditCalcRuntime.reclaimSessionAfterUnlock();
  }

  @override
  void initState() {
    super.initState();
    _syncMaintenance(FirebaseAuth.instance.currentUser);
    _authSub = FirebaseAuth.instance.authStateChanges().listen(_syncMaintenance);
  }

  void _syncMaintenance(User? user) {
    if (user == null) {
      MaintenanceService.stop();
      PublicPlanLimitsConfigService.stop();
      unawaited(DesktopPushService.stop());
    } else {
      MaintenanceService.start();
      PublicPlanLimitsConfigService.start();
    }
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      initialData: FirebaseAuth.instance.currentUser,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            snapshot.data == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasData) {
          return BiometricLockGate(
            lockOnStart: _sessionAtLaunch,
            onUnlocked: _onBiometricUnlocked,
            child: _AuthenticatedShell(
              key: ValueKey(snapshot.data!.uid),
              user: snapshot.data!,
            ),
          );
        }
        return const PublicHomePage();
      },
    );
  }
}

class _AuthenticatedShell extends StatefulWidget {
  const _AuthenticatedShell({super.key, required this.user});

  final User user;

  @override
  State<_AuthenticatedShell> createState() => _AuthenticatedShellState();
}

class _AuthenticatedShellState extends State<_AuthenticatedShell> {
  bool _checkingAccess = true;
  String? _waitingStatus;
  bool _showOnboarding = false;

  @override
  void initState() {
    super.initState();
    FcmService.syncForCurrentUser();
    _checkAccess();
  }

  Future<void> _checkAccess() async {
    try {
      final status = await resolveWaitingAccess(widget.user).timeout(
        const Duration(seconds: 15),
        onTimeout: () => null,
      );
      if (!mounted) return;

      if (status != null) {
        setState(() {
          _waitingStatus = status;
          _checkingAccess = false;
          _showOnboarding = false;
        });
        return;
      }

      final companyDoc = await FirebaseFirestore.instance
          .collection('companies')
          .doc(widget.user.uid)
          .get()
          .timeout(const Duration(seconds: 8));
      if (!mounted) return;
      final consentsOk = await RegistrationConsentsService.ensureAcceptedOnLogin(
        context,
        uid: widget.user.uid,
        isCompany: companyDoc.exists,
      );
      if (!mounted) return;
      if (!consentsOk) {
        setState(() {
          _checkingAccess = false;
          _showOnboarding = false;
        });
        return;
      }

      final needsOnboarding = await OnboardingNavigation
          .needsOnboardingForCurrentUser()
          .timeout(const Duration(seconds: 8), onTimeout: () => false);
      if (!mounted) return;

      setState(() {
        _waitingStatus = null;
        _showOnboarding = needsOnboarding;
        _checkingAccess = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _waitingStatus = null;
        _showOnboarding = false;
        _checkingAccess = false;
      });
    }
  }

  void _onAccessGranted() {
    setState(() {
      _waitingStatus = null;
      _checkingAccess = true;
    });
    _checkAccess();
  }

  @override
  Widget build(BuildContext context) {
    if (_checkingAccess) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_waitingStatus != null) {
      return WaitingPage(
        email: widget.user.email,
        status: _waitingStatus!,
        onAccessGranted: _onAccessGranted,
      );
    }

    if (_showOnboarding) {
      return OnboardingCarouselPage(
        onFinished: () => setState(() => _showOnboarding = false),
      );
    }

    return const CreditCoreSessionCoordinator(
      child: CreditCalcBootstrapGate(),
    );
  }
}
