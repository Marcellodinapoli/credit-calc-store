import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Validazione condivisa login/registrazione CreditCalc.
abstract final class AuthFormValidation {
  static final RegExp _emailPattern = RegExp(
    r'^[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}$',
  );

  static final RegExp _passwordSpecialPattern = RegExp(
    r'[!@#$%^&*(),.?":{}|<>_\-\+=\[\]\\\/`~;]',
  );

  static bool looksLikeValidEmail(String email) => _emailPattern.hasMatch(email);

  static String? passwordRuleMessage(String password) {
    final issues = <String>[];
    if (password.length < 8) {
      issues.add('almeno 8 caratteri');
    }
    if (!_passwordSpecialPattern.hasMatch(password)) {
      issues.add('un carattere speciale');
    }
    if (issues.isEmpty) return null;
    return 'La password deve contenere ${issues.join(' e ')}.';
  }

  static Future<bool> emailRegisteredOnPlatform(String email) async {
    final lookup = await _lookupAccountByEmail(email);
    return lookup.exists;
  }

  static Future<({bool exists, String? type})> _lookupAccountByEmail(
    String email,
  ) async {
    final trimmed = email.trim();
    if (trimmed.isEmpty) {
      return (exists: false, type: null);
    }

    try {
      for (final candidate in {trimmed, trimmed.toLowerCase()}) {
        final users = await FirebaseFirestore.instance
            .collection('users')
            .where('email', isEqualTo: candidate)
            .limit(1)
            .get();
        if (users.docs.isNotEmpty) {
          final type = (users.docs.first.data()['type'] ?? '').toString();
          return (exists: true, type: type.isEmpty ? 'public' : type);
        }
      }

      for (final candidate in {trimmed, trimmed.toLowerCase()}) {
        final companies = await FirebaseFirestore.instance
            .collection('companies')
            .where('email', isEqualTo: candidate)
            .limit(1)
            .get();
        if (companies.docs.isNotEmpty) {
          return (exists: true, type: 'company');
        }
      }
    } catch (_) {
      return (exists: false, type: null);
    }

    return (exists: false, type: null);
  }

  static Future<LoginAuthFeedback> resolveLoginAuthFailure(
    FirebaseAuthException e,
    String email,
  ) async {
    switch (e.code) {
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
      case 'invalid-login-credentials':
        final lookup = await _lookupAccountByEmail(email);
        if (!lookup.exists) {
          return const LoginAuthFeedback(
            notice:
                'Nessun account registrato con questa email. Verifica l’indirizzo o registrati.',
          );
        }
        return const LoginAuthFeedback(
          passwordError: 'Password non corretta. Riprova.',
        );
      case 'user-disabled':
        return const LoginAuthFeedback(
          notice: 'Account disabilitato. Contatta l’assistenza.',
        );
      case 'invalid-email':
        return const LoginAuthFeedback(
          emailError: 'L’indirizzo email non sembra corretto.',
        );
      case 'too-many-requests':
        return const LoginAuthFeedback(
          notice: 'Troppi tentativi. Riprova tra poco.',
        );
      default:
        return const LoginAuthFeedback(
          notice: 'Accesso non riuscito. Verifica email e password.',
        );
    }
  }

  static Map<String, String> validateLogin({
    required String email,
    required String password,
  }) {
    final errors = <String, String>{};

    if (email.isEmpty) {
      errors['email'] = 'Inserisci la tua email.';
    } else if (!looksLikeValidEmail(email)) {
      errors['email'] = 'L’indirizzo email non sembra corretto.';
    }

    if (password.isEmpty) {
      errors['password'] = 'Inserisci la password.';
    }

    return errors;
  }
}

class LoginAuthFeedback {
  final String? notice;
  final String? emailError;
  final String? passwordError;

  const LoginAuthFeedback({
    this.notice,
    this.emailError,
    this.passwordError,
  });
}
