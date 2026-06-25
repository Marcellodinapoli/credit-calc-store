import 'package:credit_calc_core/credit_calc_core.dart' show PlatformAdmin;
import 'package:firebase_auth/firebase_auth.dart';

/// Utente con custom claim Firebase `admin: true` (backoffice CreditCore).
abstract final class BkAdminService {
  static bool? _cached;

  static Future<bool> isAdmin({bool forceRefresh = false}) async {
    if (FirebaseAuth.instance.currentUser == null) {
      _cached = false;
      return false;
    }
    if (!forceRefresh && _cached != null) return _cached!;

    _cached = await PlatformAdmin.isCurrentUser(forceRefresh: forceRefresh);
    return _cached!;
  }

  static void clearCache() => _cached = null;
}
