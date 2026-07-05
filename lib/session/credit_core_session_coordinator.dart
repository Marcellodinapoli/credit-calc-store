import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../offline/credit_calc_runtime.dart';
import '../offline/services/session_service.dart';
import 'credit_core_session_runtime.dart';

/// Consente l'accesso agli utenti autenticati con sessione unica per dispositivo.
class CreditCoreSessionCoordinator extends StatefulWidget {
  const CreditCoreSessionCoordinator({super.key, required this.child});

  final Widget child;

  @override
  State<CreditCoreSessionCoordinator> createState() =>
      _CreditCoreSessionCoordinatorState();
}

class _CreditCoreSessionCoordinatorState
    extends State<CreditCoreSessionCoordinator> {
  StreamSubscription<User?>? _authSub;
  User? _user;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _user = FirebaseAuth.instance.currentUser;
    _authSub = FirebaseAuth.instance.authStateChanges().listen(_onAuthChanged);
    if (_user != null) {
      unawaited(_bootstrapForUser(_user!));
    }
  }

  @override
  void dispose() {
    _authSub?.cancel();
    CreditCoreSessionRuntime.resetPendingBootstrap();
    super.dispose();
  }

  void _onAuthChanged(User? user) {
    if (user == null) {
      CreditCoreSessionRuntime.clear();
      CreditCalcRuntime.clear();
      if (!mounted) return;
      setState(() {
        _user = null;
        _ready = false;
      });
      return;
    }

    if (_user?.uid == user.uid && _ready) return;

    if (_user?.uid != user.uid) {
      CreditCoreSessionRuntime.clear();
    }

    _user = user;
    unawaited(_bootstrapForUser(user));
  }

  Future<void> _bootstrapForUser(User user) async {
    if (!mounted) return;
    setState(() => _ready = false);

    final existing = CreditCoreSessionRuntime.sessionService;
    if (existing != null &&
        existing.userId == user.uid &&
        CreditCoreSessionRuntime.bootstrapComplete) {
      await existing.retryClaim();
      if (!mounted) return;
      setState(() => _ready = true);
      return;
    }

    if (existing != null && existing.userId != user.uid) {
      CreditCoreSessionRuntime.clear();
    }

    CreditCoreSessionRuntime.bootstrapFuture ??= _runBootstrap(user);
    try {
      await CreditCoreSessionRuntime.bootstrapFuture;
    } catch (_) {
      CreditCoreSessionRuntime.bootstrapFuture = null;
      CreditCoreSessionRuntime.bootstrapComplete = false;
    }

    if (!mounted || _user?.uid != user.uid) return;

    setState(() => _ready = CreditCoreSessionRuntime.bootstrapComplete);
  }

  Future<void> _runBootstrap(User user) async {
    final service = SessionService(userId: user.uid);
    await service.initialize();
    CreditCoreSessionRuntime.sessionService = service;
    CreditCoreSessionRuntime.bootstrapComplete = true;
  }

  @override
  Widget build(BuildContext context) {
    if (_user == null) {
      return widget.child;
    }
    if (!_ready) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return widget.child;
  }
}
