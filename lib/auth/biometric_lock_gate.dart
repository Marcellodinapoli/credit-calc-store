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

  final Future<void> Function()? onUnlocked;

  const BiometricLockGate({
    super.key,
    required this.child,
    this.lockOnStart = false,
    this.onUnlocked,
  });

  /// Blocca di nuovo l'app senza disconnettere Firebase (es. Esci offline).
  static void lockAgain() {
    _BiometricLockGateState.lockAgain();
  }

  static Future<bool> canLockWithBiometric() =>
      _BiometricLockGateState.canLockWithBiometric();

  @override
  State<BiometricLockGate> createState() => _BiometricLockGateState();
}

class _BiometricLockGateState extends State<BiometricLockGate> {
  /// Sblocco già effettuato in questa esecuzione dell'app.
  static bool _unlockedThisSession = false;
  static final ValueNotifier<int> _lockGeneration = ValueNotifier(0);

  final _biometricService = BiometricService();

  bool _checking = true;
  bool _lockEnabled = false;
  bool _locked = false;

  static void lockAgain() {
    _unlockedThisSession = false;
    _lockGeneration.value++;
  }

  static Future<bool> canLockWithBiometric() async {
    if (kIsWeb) return false;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.iOS:
        return BiometricService().isBiometricAvailable();
      default:
        return false;
    }
  }

  @override
  void initState() {
    super.initState();
    _lockGeneration.addListener(_onLockRequested);
    _prepare();
  }

  @override
  void dispose() {
    _lockGeneration.removeListener(_onLockRequested);
    super.dispose();
  }

  void _onLockRequested() {
    if (!mounted || !_lockEnabled) return;
    setState(() => _locked = true);
  }

  Future<void> _unlock() async {
    await widget.onUnlocked?.call();
    if (!mounted) return;
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
