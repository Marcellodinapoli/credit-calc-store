import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

/// Servizio biometria (stesso approccio di backoffice_admin_app).
class BiometricService {
  final LocalAuthentication _localAuth = LocalAuthentication();

  Future<bool> isBiometricAvailable() async {
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      final isSupported = await _localAuth.isDeviceSupported();
      return canCheck && isSupported;
    } catch (_) {
      return false;
    }
  }

  /// Restituisce `null` se ok, altrimenti un messaggio per l'utente.
  Future<String?> authenticate() async {
    try {
      final ok = await _localAuth.authenticate(
        localizedReason: 'Accedi a CreditCalc',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );
      if (ok) return null;
      return 'Autenticazione annullata.';
    } on PlatformException catch (e) {
      debugPrint('[Biometric] ${e.code}: ${e.message}');
      return switch (e.code) {
        'NotEnrolled' =>
          'Nessuna impronta registrata sul telefono. Aggiungila nelle impostazioni.',
        'NotAvailable' || 'no_fragment_activity' =>
          'Biometria non disponibile. Riavvia l\'app dopo l\'aggiornamento.',
        'LockedOut' || 'PermanentlyLockedOut' =>
          'Troppi tentativi. Riprova tra qualche minuto.',
        'PasscodeNotSet' =>
          'Imposta un blocco schermo (PIN/impronta) nelle impostazioni del telefono.',
        _ => 'Autenticazione biometrica non riuscita.',
      };
    } catch (e) {
      debugPrint('[Biometric] $e');
      return 'Autenticazione biometrica non riuscita.';
    }
  }
}
