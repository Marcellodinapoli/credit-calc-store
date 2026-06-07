import 'package:credit_calc_core/credit_calc_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'auth/login_page.dart';
import 'auth/waiting_page.dart';
import 'core/credit_calc_host.dart';
import 'services/fcm_service.dart';
import 'shell/credit_calc_shell.dart';

class CreditCalcApp extends StatefulWidget {
  const CreditCalcApp({super.key});

  @override
  State<CreditCalcApp> createState() => _CreditCalcAppState();
}

class _CreditCalcAppState extends State<CreditCalcApp> {
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
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasData) {
          return _AuthenticatedShell(
            key: ValueKey(snapshot.data!.uid),
            user: snapshot.data!,
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

    return const CreditCalcShell();
  }
}
