import 'package:cloud_firestore/cloud_firestore.dart';

/// Coupon registrazione — Firestore `coupons/{CODICE_NORMALIZZATO}`.
class RegistrationCouponValidation {
  final String code;
  final bool isValid;
  final bool lifetimeFree;
  final String? restrictedPlan;
  final DateTime? benefitExpiresAt;

  const RegistrationCouponValidation({
    required this.code,
    required this.isValid,
    this.lifetimeFree = false,
    this.restrictedPlan,
    this.benefitExpiresAt,
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

      final type = (data['type'] ?? '').toString().trim().toLowerCase();
      if (type == 'reset_limits') return RegistrationCouponValidation.invalid;

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
      final benefitExpiresAt = data['benefitExpiresAt'];
      DateTime? benefitEnd;
      if (benefitExpiresAt is Timestamp) {
        benefitEnd = benefitExpiresAt.toDate();
      }
      return RegistrationCouponValidation(
        code: code,
        isValid: true,
        lifetimeFree:
            (data['lifetimeFree'] as bool? ?? true) && benefitEnd == null,
        restrictedPlan: plan.isEmpty ? null : plan,
        benefitExpiresAt: benefitEnd,
      );
    } catch (_) {
      return RegistrationCouponValidation.invalid;
    }
  }

  static Map<String, dynamic> subscriptionFields({
    required String planId,
    RegistrationCouponValidation? coupon,
  }) {
    if (coupon != null && coupon.isValid) {
      if (coupon.lifetimeFree) {
        return {
          'subscriptionPlan': planId,
          'subscriptionStatus': 'active',
          'couponCode': coupon.code,
          'lifetimeAccess': true,
          'couponAppliedAt': FieldValue.serverTimestamp(),
        };
      }
      if (coupon.benefitExpiresAt != null) {
        return {
          'subscriptionPlan': planId,
          'subscriptionStatus': 'active',
          'couponCode': coupon.code,
          'lifetimeAccess': false,
          'subscriptionExpiresAt':
              Timestamp.fromDate(coupon.benefitExpiresAt!),
          'couponAppliedAt': FieldValue.serverTimestamp(),
        };
      }
    }

    return {
      'subscriptionPlan': planId,
      'subscriptionStatus': planId == 'free' ? 'active' : 'pending',
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
