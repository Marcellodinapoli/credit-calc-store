import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:credit_calc_core/credit_calc_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../offline/services/connectivity_service.dart';
import '../pages/area/direct_support_page.dart';
import 'login_page.dart';

Future<({Map<String, dynamic> source, bool fromCompany})?> findAccountBlockSource(
  Map<String, dynamic> userData,
  String uid,
) async {
  final userStatus = (userData['status'] ?? '').toString();
  if (UserAccountStatus.isBlocked(userStatus)) {
    return (source: userData, fromCompany: false);
  }

  final companyIds = <String>{
    if ((userData['companyId'] ?? '').toString().isNotEmpty)
      (userData['companyId'] ?? '').toString(),
    if ((userData['type'] ?? '').toString() == 'company') uid,
  };

  for (final companyId in companyIds) {
    final companyDoc = await FirebaseFirestore.instance
        .collection('companies')
        .doc(companyId)
        .get();
    if (!companyDoc.exists) continue;

    final companyData = companyDoc.data()!;
    final companyStatus = (companyData['status'] ?? '').toString();
    if (UserAccountStatus.isBlocked(companyStatus)) {
      return (source: companyData, fromCompany: true);
    }
  }

  return null;
}

/// Restituisce lo stato waiting (`pending`, `blocked`, `standby`, …) o `null` se accesso ok.
Future<String?> resolveWaitingAccess(User user) async {
  final online = await ConnectivityService.isOnline();

  if (!online) {
    // Sessione Firebase già attiva: consenti l'accesso offline con biometria.
    // Verifica email/account riprende quando torna la rete.
    return null;
  }

  try {
    await user.reload();
  } catch (_) {
    final current = FirebaseAuth.instance.currentUser ?? user;
    if (!current.emailVerified) return 'pending';
    return null;
  }

  final current = FirebaseAuth.instance.currentUser;
  if (current == null) return 'pending';

  if (!current.emailVerified) {
    return 'pending';
  }

  try {
    final userDoc =
        await FirebaseFirestore.instance.collection('users').doc(current.uid).get();
    if (!userDoc.exists) return null;

    final block = await findAccountBlockSource(userDoc.data()!, current.uid);
    if (block == null) return null;

    return (block.source['status'] ?? 'blocked').toString();
  } catch (_) {
    return null;
  }
}

class WaitingPage extends StatefulWidget {
  final String? email;
  final String status;
  final VoidCallback? onAccessGranted;

  const WaitingPage({
    super.key,
    this.email,
    this.status = 'pending',
    this.onAccessGranted,
  });

  @override
  State<WaitingPage> createState() => _WaitingPageState();
}

class _WaitingPageState extends State<WaitingPage> {
  bool _blocked = false;
  bool _pendingEmail = false;
  bool _accessGranted = false;
  String? _blockReason;
  String _blockDateLabel = '—';
  bool _blockFromCompany = false;
  String _accountStatus = '';
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _accountStatus = widget.status;
    _blocked = UserAccountStatus.isBlocked(widget.status);
    _pendingEmail = widget.status == 'pending' && !_blocked;
    _startChecks();
    Future.microtask(_pollAccountStatus);
  }

  void _startChecks() {
    _timer = Timer.periodic(const Duration(seconds: 3), (_) {
      _pollAccountStatus();
    });
  }

  void _applyBlockDetails(
    Map<String, dynamic>? source, {
    required bool fromCompany,
  }) {
    final reason = UserAccountStatus.blockReason(source);
    final status = (source?['status'] ?? '').toString();

    if (!mounted) return;
    setState(() {
      _blockReason = reason;
      _blockDateLabel = UserAccountStatus.formatBlockDateTime(
        UserAccountStatus.blockDate(source),
      );
      _blockFromCompany = fromCompany;
      _pendingEmail = false;
      if (status.isNotEmpty) _accountStatus = status;
    });
  }

  Future<void> _grantAccess() async {
    if (_accessGranted) return;
    setState(() {
      _accessGranted = true;
      _blocked = false;
      _pendingEmail = false;
    });
    _timer?.cancel();
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    widget.onAccessGranted?.call();
  }

  Future<void> _pollAccountStatus() async {
    if (!mounted || _accessGranted) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await user.reload();
    await user.getIdToken(true);

    final refreshedUser = FirebaseAuth.instance.currentUser;
    if (refreshedUser == null || !mounted) return;

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(refreshedUser.uid)
        .get();

    if (!userDoc.exists || !mounted) return;

    final block =
        await findAccountBlockSource(userDoc.data()!, refreshedUser.uid);

    if (block != null) {
      if (!_blocked) {
        setState(() => _blocked = true);
      }
      _applyBlockDetails(block.source, fromCompany: block.fromCompany);
      return;
    }

    if (!refreshedUser.emailVerified) {
      if (!_pendingEmail || _blocked) {
        setState(() {
          _blocked = false;
          _pendingEmail = true;
          _blockReason = null;
          _blockDateLabel = '—';
          _blockFromCompany = false;
          _accountStatus = 'pending';
        });
      }
      return;
    }

    await _grantAccess();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Color activeColor = Colors.yellow;
    String title = 'Conferma la tua email';
    String message =
        'Ti abbiamo inviato un’email.\n'
        'Apri il link di conferma e torna su questa pagina.';

    if (_accessGranted) {
      activeColor = Colors.green;
      title = 'Verifica completata!';
      message = 'Accesso in corso…';
    } else if (_blocked) {
      if (_accountStatus == 'standby') {
        activeColor = Colors.orange;
        title = 'Account in stand-by';
        message =
            'Il supervisor ha sospeso temporaneamente il tuo accesso.\n'
            'Contatta il supporto se necessario.';
      } else {
        activeColor = Colors.red;
        title = 'Account non attivo';
        message =
            'Il tuo account è stato bloccato o disattivato.\n'
            'Contatta il supporto per maggiori informazioni.';
      }
    } else if (_pendingEmail) {
      activeColor = Colors.yellow;
      title = 'Conferma la tua email';
      message =
          'Ti abbiamo inviato un’email.\n'
          'Apri il link di conferma e torna su questa pagina.';
      if (widget.email != null && widget.email!.isNotEmpty) {
        message += '\n\n${widget.email}';
      }
    }

    return Scaffold(
      backgroundColor: AppTheme.body,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Card(
                elevation: 4,
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: Color(0xFFE0E0E0)),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: const Border(
                      left: BorderSide(color: AppTheme.accent, width: 4),
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 36,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.accent,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      _buildTrafficLight(activeColor),
                      const SizedBox(height: 28),
                      Text(
                        message,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 15,
                          height: 1.45,
                          color: Color(0xFF424242),
                        ),
                      ),
                      if (_blocked && !_accessGranted) ...[
                        const SizedBox(height: 20),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF5F7FA),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE0E6ED)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (_blockFromCompany) ...[
                                const Text(
                                  'Blocco applicato all’azienda collegata al tuo profilo.',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.black54,
                                  ),
                                ),
                                const SizedBox(height: 12),
                              ],
                              _buildBlockInfoRow(
                                _accountStatus == 'standby'
                                    ? 'Data stand-by'
                                    : 'Data blocco',
                                _blockDateLabel,
                              ),
                              const SizedBox(height: 12),
                              _buildBlockInfoRow(
                                'Motivazione',
                                (_blockReason != null &&
                                        _blockReason!.isNotEmpty)
                                    ? _blockReason!
                                    : '—',
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 28),
                      if (_blocked && !_accessGranted)
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute<void>(
                                  builder: (_) => const DirectSupportPage(),
                                ),
                              );
                            },
                            style: FilledButton.styleFrom(
                              backgroundColor: AppTheme.accent,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            icon: const Icon(Icons.support_agent),
                            label: const Text('Contatta supporto'),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBlockInfoRow(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
            color: AppTheme.accent,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 15,
            height: 1.4,
            color: Color(0xFF1A1A1A),
          ),
        ),
      ],
    );
  }

  Widget _buildTrafficLight(Color activeColor) {
    const lights = [
      Colors.red,
      Colors.orange,
      Colors.yellow,
      Colors.green,
    ];
    return Container(
      width: 72,
      height: 220,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: lights.map((color) {
          final isActive = color == activeColor;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 500),
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: isActive ? color : color.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
          );
        }).toList(),
      ),
    );
  }
}
