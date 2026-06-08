import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../services/biometric_service.dart';
import 'login_page.dart';

/// Chiede login/biometria solo alla riapertura dell'app (processo nuovo).
/// In background o cambiando schermata la sessione resta attiva.
class BiometricLockGate extends StatefulWidget {
  final Widget child;

  /// `true` se la sessione Firebase esisteva già all'avvio del processo.
  final bool lockOnStart;

  const BiometricLockGate({
    super.key,
    required this.child,
    this.lockOnStart = false,
  });

  @override
  State<BiometricLockGate> createState() => _BiometricLockGateState();
}

class _BiometricLockGateState extends State<BiometricLockGate> {
  /// Sblocco già effettuato in questa esecuzione dell'app.
  static bool _unlockedThisSession = false;

  final _biometricService = BiometricService();

  bool _checking = true;
  bool _lockEnabled = false;
  bool _locked = false;

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  void _unlock() {
    _unlockedThisSession = true;
    setState(() => _locked = false);
  }

  Future<void> _prepare() async {
    final enabled = await _isLockSupported();
    if (!mounted) return;
    final lockNow =
        enabled && widget.lockOnStart && !_unlockedThisSession;
    setState(() {
      _lockEnabled = enabled;
      _locked = lockNow;
      _checking = false;
    });
  }

  Future<bool> _isLockSupported() async {
    if (kIsWeb) return false;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.iOS:
        return _biometricService.isBiometricAvailable();
      default:
        return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_lockEnabled && _locked) {
      return LoginPage(
        unlockMode: true,
        onUnlocked: _unlock,
      );
    }

    return widget.child;
  }
}
