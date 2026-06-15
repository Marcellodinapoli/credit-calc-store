import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../auth/login_page.dart';
import 'credit_core_session_runtime.dart';

/// Disconnessione quando un altro dispositivo prende la sessione CreditCore.
abstract final class SessionRevokedLogout {
  static bool _inProgress = false;

  static Future<void> perform(BuildContext context) async {
    if (_inProgress) return;
    _inProgress = true;

    try {
      if (context.mounted) {
        await showDialog<void>(
          context: context,
          barrierDismissible: false,
          useRootNavigator: true,
          builder: (ctx) => AlertDialog(
            title: const Text('Sessione aperta altrove'),
            content: const Text(
              'CreditCore è stato aperto su un altro dispositivo '
              '(web o app).\n\n'
              'Per evitare conflitti su Form, Calc, Job e dati condivisi '
              'verrai disconnesso da questa sessione.',
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.of(ctx, rootNavigator: true).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }

      await CreditCoreSessionRuntime.sessionService?.releaseSession();
      CreditCoreSessionRuntime.clear();
      await FirebaseAuth.instance.signOut();

      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginPage()),
        (_) => false,
      );
    } finally {
      _inProgress = false;
    }
  }
}
