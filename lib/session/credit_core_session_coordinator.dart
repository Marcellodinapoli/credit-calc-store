import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../auth/login_page.dart';
import '../offline/services/session_service.dart';
import '../widgets/session_takeover_dialog.dart';
import 'credit_core_session_runtime.dart';
import 'session_revoked_logout.dart';

enum _GateState { bootstrapping, ready, blocked }

/// Blocca l'app finché la sessione piattaforma non è risolta (un solo accesso).
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
  _GateState _state = _GateState.bootstrapping;

  @override
  void initState() {
    super.initState();
    CreditCoreSessionRuntime.sessionRevoked.addListener(_onSessionRevoked);
    _user = FirebaseAuth.instance.currentUser;
    _authSub = FirebaseAuth.instance.authStateChanges().listen(_onAuthChanged);
    if (_user != null) {
      unawaited(_bootstrapForUser(_user!));
    }
  }

  @override
  void dispose() {
    CreditCoreSessionRuntime.sessionRevoked.removeListener(_onSessionRevoked);
    _authSub?.cancel();
    CreditCoreSessionRuntime.resetPendingBootstrap();
    super.dispose();
  }

  void _onSessionRevoked() {
    if (!CreditCoreSessionRuntime.sessionRevoked.value || !mounted) return;
    unawaited(SessionRevokedLogout.perform(context));
  }

  void _onAuthChanged(User? user) {
    if (user == null) {
      CreditCoreSessionRuntime.clear();
      if (!mounted) return;
      setState(() {
        _user = null;
        _state = _GateState.bootstrapping;
      });
      return;
    }

    if (_user?.uid == user.uid &&
        _state == _GateState.ready &&
        CreditCoreSessionRuntime.isSessionReady) {
      return;
    }

    if (_user?.uid != user.uid) {
      CreditCoreSessionRuntime.clear();
    }

    _user = user;
    unawaited(_bootstrapForUser(user));
  }

  Future<void> _returnToLogin() async {
    await CreditCoreSessionRuntime.sessionService?.releaseSession();
    CreditCoreSessionRuntime.clear();
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    setState(() {
      _user = null;
      _state = _GateState.bootstrapping;
    });
    Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (_) => false,
    );
  }

  Future<void> _bootstrapForUser(User user) async {
    if (!mounted) return;
    setState(() => _state = _GateState.bootstrapping);

    final existing = CreditCoreSessionRuntime.sessionService;
    if (existing != null &&
        existing.userId == user.uid &&
        CreditCoreSessionRuntime.isSessionReady &&
        await existing.holdsActiveSession()) {
      if (!mounted) return;
      setState(() => _state = _GateState.ready);
      return;
    }

    if (existing != null && existing.userId != user.uid) {
      CreditCoreSessionRuntime.clear();
    }

    if (!CreditCoreSessionRuntime.bootstrapComplete) {
      CreditCoreSessionRuntime.bootstrapFuture = null;
    }

    CreditCoreSessionRuntime.bootstrapFuture ??= _runBootstrap(user);
    try {
      await CreditCoreSessionRuntime.bootstrapFuture;
    } catch (_) {
      CreditCoreSessionRuntime.bootstrapFuture = null;
      CreditCoreSessionRuntime.bootstrapComplete = false;
    }

    if (!CreditCoreSessionRuntime.bootstrapComplete) {
      CreditCoreSessionRuntime.bootstrapFuture = null;
    }

    if (!mounted || _user?.uid != user.uid) return;

    if (CreditCoreSessionRuntime.sessionRevoked.value) {
      unawaited(SessionRevokedLogout.perform(context));
      return;
    }

    final service = CreditCoreSessionRuntime.sessionService;
    final holds = service != null && await service.holdsActiveSession();
    if (!mounted || _user?.uid != user.uid) return;

    setState(() {
      if (holds && CreditCoreSessionRuntime.bootstrapComplete) {
        _state = _GateState.ready;
      } else {
        _state = _GateState.blocked;
      }
    });
  }

  Future<void> _runBootstrap(User user) async {
    final service = SessionService(userId: user.uid);
    CreditCoreSessionRuntime.sessionService = service;

    service.startWatching(
      onSessionRevoked: CreditCoreSessionRuntime.handleSessionRevoked,
    );

    if (await service.syncOwnershipFromRemote()) {
      CreditCoreSessionRuntime.bootstrapComplete = true;
      CreditCoreSessionRuntime.startHeartbeat(service);
      return;
    }

    if (!mounted) return;

    final conflict = await service.findConflictingSession();
    if (!mounted) return;

    if (conflict != null) {
      final proceed = await showSessionTakeoverDialog(context, conflict);
      if (!proceed || !mounted) {
        CreditCoreSessionRuntime.bootstrapFuture = null;
        CreditCoreSessionRuntime.bootstrapComplete = false;
        await FirebaseAuth.instance.signOut();
        return;
      }
    }

    await service.claimSession(refreshSessionId: true);
    CreditCoreSessionRuntime.bootstrapComplete = true;
    CreditCoreSessionRuntime.startHeartbeat(service);
  }

  @override
  Widget build(BuildContext context) {
    switch (_state) {
      case _GateState.bootstrapping:
        return const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        );
      case _GateState.blocked:
        return Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Un solo accesso alla volta',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'CreditCore può restare aperto su un solo browser o '
                      'dispositivo per volta (web, app desktop o telefono).\n\n'
                      'Chiudi l\'altra sessione oppure prendi il controllo da qui.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.grey.shade700,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: () {
                        CreditCoreSessionRuntime.bootstrapFuture = null;
                        CreditCoreSessionRuntime.bootstrapComplete = false;
                        final user = _user;
                        if (user != null) {
                          unawaited(_bootstrapForUser(user));
                        }
                      },
                      child: const Text('Prendi il controllo'),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _returnToLogin,
                      child: const Text('Esci e riprova'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      case _GateState.ready:
        return widget.child;
    }
  }
}
