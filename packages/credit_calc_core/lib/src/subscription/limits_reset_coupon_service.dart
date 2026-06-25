import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'public_usage_service.dart';

/// Coupon backoffice (`coupons/{codice}` con `type: reset_limits`).
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
  static const couponType = 'reset_limits';

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

        final type = (data['type'] ?? '').toString().trim().toLowerCase();
        if (type != couponType) {
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

        tx.update(ref, {
          'usedCount': count + 1,
          'lastUsedAt': FieldValue.serverTimestamp(),
          'lastUsedBy': uid,
        });
      });

      await PublicUsageService.resetMonthlyUsage();

      return LimitsResetCouponResult(
        success: true,
        code: code,
        message:
            'Limiti mensili azzerati. Puoi continuare a usare la piattaforma.',
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
}

class _CouponRedeemException implements Exception {
  _CouponRedeemException(this.message);
  final String message;
}
