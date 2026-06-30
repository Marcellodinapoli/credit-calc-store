import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'public_usage_service.dart';

/// Coupon backoffice (`coupons/{codice}`) — azzera limiti e aggiorna piano/scadenza.
class LimitsResetCouponResult {
  const LimitsResetCouponResult({
    required this.success,
    this.message,
    this.code,
  });

  final bool success;
  final String? message;
  final String? code;
}

abstract final class LimitsResetCouponService {
  static const couponTypeReset = 'reset_limits';

  static String normalizeCode(String raw) =>
      raw.trim().toUpperCase().replaceAll(RegExp(r'\s+'), '');

  static Future<LimitsResetCouponResult> redeem(String raw) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const LimitsResetCouponResult(
        success: false,
        message: 'Sessione scaduta. Effettua di nuovo l\'accesso.',
      );
    }

    final code = normalizeCode(raw);
    if (code.isEmpty) {
      return const LimitsResetCouponResult(
        success: false,
        message: 'Inserisci un codice coupon.',
      );
    }

    final ref = FirebaseFirestore.instance.collection('coupons').doc(code);
    Map<String, dynamic>? couponData;

    try {
      await FirebaseFirestore.instance.runTransaction((tx) async {
        final snap = await tx.get(ref);
        if (!snap.exists) {
          throw _CouponRedeemException('Coupon non valido.');
        }

        final data = snap.data() ?? {};
        if (data['enabled'] != true) {
          throw _CouponRedeemException('Coupon non attivo.');
        }

        if (!_isRedeemableInMyData(data['type']?.toString())) {
          throw _CouponRedeemException(
            'Questo coupon non è valido per azzerare i limiti.',
          );
        }

        final expiresAt = data['expiresAt'];
        if (expiresAt is Timestamp &&
            expiresAt.toDate().isBefore(DateTime.now())) {
          throw _CouponRedeemException('Coupon scaduto.');
        }

        final maxUses = data['maxUses'];
        final usedCount = data['usedCount'];
        if (maxUses is num && usedCount is num && usedCount >= maxUses) {
          throw _CouponRedeemException('Coupon esaurito.');
        }

        final count = usedCount is int
            ? usedCount
            : usedCount is num
                ? usedCount.toInt()
                : 0;

        couponData = Map<String, dynamic>.from(data);
        tx.update(ref, {
          'usedCount': count + 1,
          'lastUsedAt': FieldValue.serverTimestamp(),
          'lastUsedBy': uid,
        });
      });

      await PublicUsageService.resetMonthlyUsage();

      final data = couponData;
      if (data != null) {
        await _applySubscriptionFromCoupon(uid, code, data);
      }

      return LimitsResetCouponResult(
        success: true,
        code: code,
        message: data == null
            ? 'Limiti mensili azzerati. Puoi continuare a usare la piattaforma.'
            : _successMessage(data),
      );
    } on _CouponRedeemException catch (e) {
      return LimitsResetCouponResult(success: false, message: e.message);
    } catch (_) {
      return const LimitsResetCouponResult(
        success: false,
        message: 'Impossibile applicare il coupon. Riprova più tardi.',
      );
    }
  }

  /// Accetta coupon «azzera limiti» e coupon registrazione creati dal backoffice.
  static bool _isRedeemableInMyData(String? rawType) {
    final type = (rawType ?? '').trim().toLowerCase();
    if (type.isEmpty || type == 'registration') return true;
    return type == couponTypeReset;
  }

  static Future<void> _applySubscriptionFromCoupon(
    String uid,
    String code,
    Map<String, dynamic> data,
  ) async {
    final plan = (data['plan'] ?? '').toString().trim().toLowerCase();
    final lifetimeFree = data['lifetimeFree'] == true;
    final benefitExpiresAt = data['benefitExpiresAt'];

    final updates = <String, dynamic>{
      'couponCode': code,
      'couponAppliedAt': FieldValue.serverTimestamp(),
    };

    final hasPlan = _isKnownPlan(plan);
    final hasBenefitExpiry = benefitExpiresAt is Timestamp;

    if (hasPlan) {
      updates['subscriptionPlan'] = plan;
    }

    if (hasBenefitExpiry) {
      updates['lifetimeAccess'] = FieldValue.delete();
      updates['subscriptionStatus'] = 'active';
      updates['subscriptionExpiresAt'] = benefitExpiresAt;
    } else if (lifetimeFree) {
      updates['lifetimeAccess'] = true;
      updates['subscriptionStatus'] = 'active';
      updates['subscriptionExpiresAt'] = FieldValue.delete();
    } else if (hasPlan) {
      updates['lifetimeAccess'] = FieldValue.delete();
      updates['subscriptionStatus'] = 'active';
    }

    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .set(updates, SetOptions(merge: true));
  }

  static bool _isKnownPlan(String plan) =>
      plan == 'free' || plan == 'plus' || plan == 'enterprise';

  static String _successMessage(Map<String, dynamic> data) {
    final parts = <String>['Limiti mensili azzerati.'];
    final plan = (data['plan'] ?? '').toString().trim().toLowerCase();
    if (_isKnownPlan(plan)) {
      parts.add('Piano aggiornato: ${_planLabel(plan)}.');
    }
    if (data['lifetimeFree'] == true) {
      parts.add('Accesso attivo senza scadenza.');
    } else if (data['benefitExpiresAt'] is Timestamp) {
      final d = (data['benefitExpiresAt'] as Timestamp).toDate();
      final day = d.day.toString().padLeft(2, '0');
      final month = d.month.toString().padLeft(2, '0');
      parts.add('Effetto attivo fino al $day/$month/${d.year}.');
    }
    return parts.join(' ');
  }

  static String _planLabel(String plan) => switch (plan) {
        'plus' => 'Plus',
        'enterprise' => 'Enterprise',
        _ => 'Gratis',
      };
}

class _CouponRedeemException implements Exception {
  _CouponRedeemException(this.message);
  final String message;
}
