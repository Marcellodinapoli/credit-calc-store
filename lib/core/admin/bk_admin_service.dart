import 'package:firebase_auth/firebase_auth.dart';

/// Utente con custom claim Firebase `admin: true` (backoffice CreditCore).
abstract final class BkAdminService {
  static bool? _cached;

  static Future<bool> isAdmin({bool forceRefresh = false}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _cached = false;
      return false;
    }
    if (!forceRefresh && _cached != null) return _cached!;

    try {
      final token = await user.getIdTokenResult(forceRefresh);
      _cached = token.claims?['admin'] == true;
      return _cached!;
    } catch (_) {
      _cached = false;
      return false;
    }
  }

  static void clearCache() => _cached = null;
}
