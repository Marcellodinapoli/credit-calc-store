import 'package:credit_calc_core/credit_calc_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'auth/login_page.dart';
import 'auth/waiting_page.dart';
import 'core/credit_calc_host.dart';
import 'services/fcm_service.dart';
import 'shell/credit_calc_shell.dart';
import 'widgets/credit_calc_maintenance_gate.dart';

class CreditCalcApp extends StatefulWidget {
  const CreditCalcApp({super.key});

  @override
  State<CreditCalcApp> createState() => _CreditCalcAppState();
}

class _CreditCalcAppState extends State<CreditCalcApp> {
  final ValueNotifier<bool> _maintenanceGateEnabled = ValueNotifier(false);

  @override
  void dispose() {
    _maintenanceGateEnabled.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    registerCreditCalcHost();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CreditCalc',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: ProjectColors.calc),
        useMaterial3: true,
      ),
      builder: (context, child) {
        return ValueListenableBuilder<bool>(
          valueListenable: _maintenanceGateEnabled,
          builder: (context, enabled, _) {
            if (!enabled || child == null) return child ?? const SizedBox.shrink();
            return CreditCalcMaintenanceGate(child: child);
          },
        );
      },
      home: _AuthGate(maintenanceGateEnabled: _maintenanceGateEnabled),
    );
  }
}

class _AuthGate extends StatefulWidget {
  final ValueNotifier<bool> maintenanceGateEnabled;

  const _AuthGate({required this.maintenanceGateEnabled});

  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          widget.maintenanceGateEnabled.value = false;
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasData) {
          return _AuthenticatedShell(
            key: ValueKey(snapshot.data!.uid),
            user: snapshot.data!,
            maintenanceGateEnabled: widget.maintenanceGateEnabled,
          );
        }
        widget.maintenanceGateEnabled.value = false;
        return const LoginPage();
      },
    );
  }
}

class _AuthenticatedShell extends StatefulWidget {
  final User user;
  final ValueNotifier<bool> maintenanceGateEnabled;

  const _AuthenticatedShell({
    super.key,
    required this.user,
    required this.maintenanceGateEnabled,
  });

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

  @override
  void dispose() {
    widget.maintenanceGateEnabled.value = false;
    super.dispose();
  }

  Future<void> _checkAccess() async {
    final status = await resolveWaitingAccess(widget.user);
    if (!mounted) return;
    setState(() {
      _waitingStatus = status;
      _checkingAccess = false;
    });
  }

  void _onAccessGranted() {
    setState(() => _waitingStatus = null);
  }

  @override
  Widget build(BuildContext context) {
    if (_checkingAccess) {
      widget.maintenanceGateEnabled.value = false;
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_waitingStatus != null) {
      widget.maintenanceGateEnabled.value = false;
      return WaitingPage(
        email: widget.user.email,
        status: _waitingStatus!,
        onAccessGranted: _onAccessGranted,
      );
    }

    widget.maintenanceGateEnabled.value = true;
    return const CreditCalcShell();
  }
}
