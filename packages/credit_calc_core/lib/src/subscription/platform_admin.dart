import 'package:firebase_auth/firebase_auth.dart';

/// Amministratori piattaforma: claim Firebase `admin: true` o email bootstrap.
abstract final class PlatformAdmin {
  static const bootstrapEmails = <String>{
    'dinapoli.marcello@gmail.com',
  };

  static bool isBootstrapEmail(String? email) {
    final normalized = (email ?? '').trim().toLowerCase();
    return bootstrapEmails.contains(normalized);
  }

  static Future<bool> isCurrentUser({bool forceRefresh = false}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;
    if (isBootstrapEmail(user.email)) return true;
    try {
      final token = await user.getIdTokenResult(forceRefresh);
      return token.claims?['admin'] == true;
    } catch (_) {
      return false;
    }
  }
}
