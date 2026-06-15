import 'package:cloud_firestore/cloud_firestore.dart';

/// Coupon registrazione — Firestore `coupons/{CODICE_NORMALIZZATO}`.
class RegistrationCouponValidation {
  final String code;
  final bool isValid;
  final bool lifetimeFree;
  final String? restrictedPlan;

  const RegistrationCouponValidation({
    required this.code,
    required this.isValid,
    this.lifetimeFree = false,
    this.restrictedPlan,
  });

  static const invalid = RegistrationCouponValidation(
    code: '',
    isValid: false,
  );
}

abstract final class RegistrationCouponService {
  static String normalizeCode(String raw) =>
      raw.trim().toUpperCase().replaceAll(RegExp(r'\s+'), '');

  static Future<RegistrationCouponValidation> validate(String raw) async {
    final code = normalizeCode(raw);
    if (code.isEmpty) return RegistrationCouponValidation.invalid;

    try {
      final snap = await FirebaseFirestore.instance
          .collection('coupons')
          .doc(code)
          .get()
          .timeout(const Duration(seconds: 8));

      if (!snap.exists) return RegistrationCouponValidation.invalid;

      final data = snap.data() ?? {};
      if (data['enabled'] != true) return RegistrationCouponValidation.invalid;

      final expiresAt = data['expiresAt'];
      if (expiresAt is Timestamp && expiresAt.toDate().isBefore(DateTime.now())) {
        return RegistrationCouponValidation.invalid;
      }

      final maxUses = data['maxUses'];
      final usedCount = data['usedCount'];
      if (maxUses is num && usedCount is num && usedCount >= maxUses) {
        return RegistrationCouponValidation.invalid;
      }

      final plan = (data['plan'] ?? '').toString().trim().toLowerCase();
      return RegistrationCouponValidation(
        code: code,
        isValid: true,
        lifetimeFree: data['lifetimeFree'] as bool? ?? true,
        restrictedPlan: plan.isEmpty ? null : plan,
      );
    } catch (_) {
      return RegistrationCouponValidation.invalid;
    }
  }

  static Map<String, dynamic> subscriptionFields({
    required String planId,
    RegistrationCouponValidation? coupon,
  }) {
    final lifetime =
        coupon != null && coupon.isValid && coupon.lifetimeFree;

    return {
      'subscriptionPlan': planId,
      'subscriptionStatus': lifetime || planId == 'free' ? 'active' : 'pending',
      if (lifetime) ...{
        'couponCode': coupon.code,
        'lifetimeAccess': true,
      },
    };
  }

  static Future<void> markCouponUsed({
    required String code,
    required String userId,
  }) async {
    final normalized = normalizeCode(code);
    if (normalized.isEmpty) return;

    final ref = FirebaseFirestore.instance.collection('coupons').doc(normalized);
    await FirebaseFirestore.instance.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) return;
      final data = snap.data() ?? {};
      if (data['enabled'] != true) return;

      final current = data['usedCount'];
      final count = current is int
          ? current
          : current is num
              ? current.toInt()
              : 0;

      tx.update(ref, {
        'usedCount': count + 1,
        'lastUsedAt': FieldValue.serverTimestamp(),
        'lastUsedBy': userId,
      });
    });
  }
}
