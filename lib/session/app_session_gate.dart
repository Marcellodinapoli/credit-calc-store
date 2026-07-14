import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../offline/models/session_info.dart';
import '../pages/creditcalc/device_sync_page.dart';
import '../session/credit_core_session_runtime.dart';
import '../offline/services/session_service.dart';
import '../widgets/app_session_conflict_dialog.dart';

/// Blocco app intero: sul secondo dispositivo resta accessibile solo Sincronizza.
class AppSessionGate extends StatefulWidget {
  const AppSessionGate({super.key, required this.child});

  final Widget child;

  @override
  State<AppSessionGate> createState() => _AppSessionGateState();
}

class _AppSessionGateState extends State<AppSessionGate> {
  StreamSubscription<AppSessionRole>? _roleSub;
  StreamSubscription<User?>? _authSub;
  Timer? _retryTimer;
  bool _dialogShown = false;
  String? _attachedUserId;

  SessionService? get _session => CreditCoreSessionRuntime.sessionService;

  @override
  void initState() {
    super.initState();
    _attachSession(_session);
    _authSub = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (!mounted) return;
      final uid = user?.uid;
      if (uid == _attachedUserId) return;
      _attachedUserId = uid;
      if (uid == null) _dialogShown = false;
      _attachSession(_session);
      setState(() {});
    });
    _startAutoRetry();
  }

  @override
  void dispose() {
    _roleSub?.cancel();
    _authSub?.cancel();
    _retryTimer?.cancel();
    super.dispose();
  }

  void _attachSession(SessionService? session) {
    _roleSub?.cancel();
    if (session == null) return;

    _roleSub = session.roleStream.listen((role) {
      if (!mounted) return;
      if (role == AppSessionRole.secondaryBlocked) {
        _maybeShowDialog(session);
      } else if (role == AppSessionRole.primary) {
        _dialogShown = false;
      }
      setState(() {});
    });

    if (session.role == AppSessionRole.secondaryBlocked) {
      _maybeShowDialog(session);
    }
  }

  void _startAutoRetry() {
    _retryTimer?.cancel();
    _retryTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      final session = _session;
      if (session == null || session.role != AppSessionRole.secondaryBlocked) {
        return;
      }
      unawaited(_retryAccess(silent: true));
    });
  }

  void _maybeShowDialog(SessionService session) {
    if (_dialogShown) return;
    _dialogShown = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (session.role != AppSessionRole.secondaryBlocked) {
        _dialogShown = false;
        return;
      }
      unawaited(
        showAppSessionConflictDialog(
          context,
          conflict: session.conflict,
        ),
      );
    });
  }

  Future<void> _retryAccess({bool silent = false}) async {
    final session = _session;
    if (session == null) return;
    await session.retryClaim();
    if (!mounted) return;
    if (!silent && session.role == AppSessionRole.primary) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Accesso sbloccato.')),
      );
      _dialogShown = false;
    }
    setState(() {});
  }

  Future<void> _logout() async {
    await CreditCoreSessionRuntime.signOutWithSessionRelease();
  }

  @override
  Widget build(BuildContext context) {
    final session = _session;
    if (session == null) return widget.child;

    if (session.role == AppSessionRole.secondaryBlocked) {
      return _SyncOnlyShell(
        conflict: session.conflict,
        onRetry: () => _retryAccess(),
        onLogout: _logout,
      );
    }

    return widget.child;
  }
}

class _SyncOnlyShell extends StatelessWidget {
  const _SyncOnlyShell({
    required this.onRetry,
    required this.onLogout,
    this.conflict,
  });

  final Future<void> Function() onRetry;
  final Future<void> Function() onLogout;
  final SessionInfo? conflict;

  @override
  Widget build(BuildContext context) {
    final deviceLine = conflict?.conflictSummary ?? 'un altro dispositivo';

    return Scaffold(
      backgroundColor: const Color(0xFFE8E8E8),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Account già in uso'),
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
        actions: [
          TextButton(
            onPressed: () => unawaited(onLogout()),
            child: const Text(
              'Esci',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            color: const Color(0xFFFFF3E0),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Hai già aperto lo stesso account su:\n\n'
                    '$deviceLine\n\n'
                    'Per usare CreditCalc su questo dispositivo devi uscire '
                    'dall\'account sul primo dispositivo.\n\n'
                    'Nel frattempo puoi accedere solo alla pagina Sincronizza.\n\n'
                    'Se hai già chiuso l\'altro dispositivo, attendi fino a '
                    'circa 1 minuto oppure premi Riprova accesso.',
                    style: TextStyle(
                      color: Colors.orange.shade900,
                      height: 1.45,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: onRetry,
                    child: const Text('Riprova accesso'),
                  ),
                ],
              ),
            ),
          ),
          const Expanded(child: DeviceSyncPage()),
        ],
      ),
    );
  }
}
