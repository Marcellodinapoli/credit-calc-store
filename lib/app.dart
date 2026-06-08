import 'package:credit_calc_core/credit_calc_core.dart';
import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'auth/biometric_lock_gate.dart';
import 'auth/login_page.dart';
import 'auth/waiting_page.dart';
import 'core/maintenance_service.dart';
import 'services/fcm_service.dart';
import 'offline/credit_calc_bootstrap_gate.dart';
import 'offline/credit_calc_runtime.dart';

class CreditCalcApp extends StatefulWidget {
  const CreditCalcApp({super.key});

  @override
  State<CreditCalcApp> createState() => _CreditCalcAppState();
}

class _CreditCalcAppState extends State<CreditCalcApp> {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CreditCalc',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: ProjectColors.calc),
        useMaterial3: true,
      ),
      home: const _AuthGate(),
    );
  }
}

class _AuthGate extends StatefulWidget {
  const _AuthGate();

  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> {
  StreamSubscription<User?>? _authSub;
  final bool _sessionAtLaunch = FirebaseAuth.instance.currentUser != null;

  @override
  void initState() {
    super.initState();
    _syncMaintenance(FirebaseAuth.instance.currentUser);
    _authSub = FirebaseAuth.instance.authStateChanges().listen(_syncMaintenance);
  }

  void _syncMaintenance(User? user) {
    if (user == null) {
      MaintenanceService.stop();
    } else {
      MaintenanceService.start();
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
            onUnlocked: CreditCalcRuntime.reclaimSessionAfterUnlock,
            child: _AuthenticatedShell(
              key: ValueKey(snapshot.data!.uid),
              user: snapshot.data!,
            ),
          );
        }
        return const LoginPage();
      },
    );
  }
}

class _AuthenticatedShell extends StatefulWidget {
  final User user;

  const _AuthenticatedShell({super.key, required this.user});

  @override
  State<_AuthenticatedShell> createState() => _AuthenticatedShellState();
}

class _AuthenticatedShellState extends State<_AuthenticatedShell> {
  bool _checkingAccess = true;
  String? _waitingStatus;

  @override
  void initState() {
    super.initState();
    FcmService.syncForCurrentUser();
    _checkAccess();
  }

  Future<void> _checkAccess() async {
    try {
      final status = await resolveWaitingAccess(widget.user);
      if (!mounted) return;
      setState(() {
        _waitingStatus = status;
        _checkingAccess = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _waitingStatus = null;
        _checkingAccess = false;
      });
    }
  }

  void _onAccessGranted() {
    setState(() => _waitingStatus = null);
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

    return const CreditCalcBootstrapGate();
  }
}
