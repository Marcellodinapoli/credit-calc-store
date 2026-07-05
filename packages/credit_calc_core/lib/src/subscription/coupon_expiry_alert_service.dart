import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'user_subscription_snapshot.dart';

enum CouponExpiryAlertPhase { advance, lastDay }

class CouponExpiryAlert {
  const CouponExpiryAlert({
    required this.phase,
    required this.expiresAt,
  });

  final CouponExpiryAlertPhase phase;
  final DateTime expiresAt;

  String get formattedDate => CouponExpiryAlertService.formatDate(expiresAt);

  String get message => switch (phase) {
        CouponExpiryAlertPhase.advance =>
          'Il coupon scade il $formattedDate. '
              'Dopo quella data torneranno i limiti del piano base.',
        CouponExpiryAlertPhase.lastDay =>
          'Oggi è l\'ultimo giorno in cui il coupon è ancora attivo '
              '(scadenza $formattedDate). '
              'Da domani torneranno i limiti del piano base.',
      };
}

/// Avvisi scadenza coupon: 3 giorni prima (una volta) e ultimo giorno attivo.
abstract final class CouponExpiryAlertService {
  static String formatDate(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}/'
      '${dt.month.toString().padLeft(2, '0')}/'
      '${dt.year}';

  static DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  static int daysUntilExpiry(DateTime expiresAt) {
    final today = _dateOnly(DateTime.now());
    final expiry = _dateOnly(expiresAt);
    return expiry.difference(today).inDays;
  }

  static String _advanceSeenKey(String uid, DateTime expiresAt) {
    final expiry = _dateOnly(expiresAt);
    return 'coupon_expiry_advance_seen_${uid}_'
        '${expiry.year}${expiry.month.toString().padLeft(2, '0')}'
        '${expiry.day.toString().padLeft(2, '0')}';
  }

  static Future<bool> isAdvanceWarningSeen(
    String uid,
    DateTime expiresAt,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_advanceSeenKey(uid, expiresAt)) ?? false;
  }

  static Future<void> markAdvanceWarningSeen(
    String uid,
    DateTime expiresAt,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_advanceSeenKey(uid, expiresAt), true);
  }

  static Future<CouponExpiryAlert?> resolveForSnapshot(
    UserSubscriptionSnapshot snapshot,
  ) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;
    if (!snapshot.hasCoupon || snapshot.lifetimeAccess) return null;

    final expiresAt = snapshot.limitsEffectExpiresAt;
    if (expiresAt == null || snapshot.isCouponLimitsEffectExpired) return null;

    final days = daysUntilExpiry(expiresAt);
    if (days == 0) {
      return CouponExpiryAlert(
        phase: CouponExpiryAlertPhase.lastDay,
        expiresAt: expiresAt,
      );
    }

    if (days == 3) {
      final seen = await isAdvanceWarningSeen(uid, expiresAt);
      if (!seen) {
        return CouponExpiryAlert(
          phase: CouponExpiryAlertPhase.advance,
          expiresAt: expiresAt,
        );
      }
    }

    return null;
  }
}
