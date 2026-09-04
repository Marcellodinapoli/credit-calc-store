import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'subscription_billing_service.dart';
import 'company_collaborator_limit_service.dart';
import 'user_subscription_snapshot.dart';

/// Lettura e aggiornamento campi abbonamento su `users` / `companies`.
abstract final class UserSubscriptionService {
  static final _firestore = FirebaseFirestore.instance;

  static Map<String, dynamic> _subscriptionFrom(Map<String, dynamic>? data) {
    final map = data ?? {};
    final couponRaw = (map['couponCode'] ?? '').toString().trim();
    return {
      'subscriptionPlan': (map['subscriptionPlan'] ?? 'free').toString(),
      'subscriptionStatus':
          (map['subscriptionStatus'] ?? 'active').toString(),
      'couponCode': couponRaw.isEmpty ? null : couponRaw,
      'lifetimeAccess': map['lifetimeAccess'] == true,
      'couponAppliedAt': map['couponAppliedAt'],
      'subscriptionExpiresAt': map['subscriptionExpiresAt'],
      'subscriptionCancelledAt': map['subscriptionCancelledAt'],
    };
  }

  /// Arricchisce abbonamento con dati dal coupon collegato (`couponCode` o uso).
  static Future<Map<String, dynamic>> _enrichSubscriptionFromCouponUsage(
    String uid,
    Map<String, dynamic> subscription,
  ) async {
    final enriched = Map<String, dynamic>.from(subscription);
    var code = (enriched['couponCode'] ?? '').toString().trim();

    if (code.isEmpty) {
      try {
        final snap = await _firestore
            .collection('coupons')
            .where('lastUsedBy', isEqualTo: uid)
            .limit(1)
            .get();
        if (snap.docs.isEmpty) return enriched;

        final doc = snap.docs.first;
        code = doc.id;
        enriched['couponCode'] = code;
        final data = doc.data();
        if (enriched['lifetimeAccess'] != true) {
          enriched['lifetimeAccess'] = data['lifetimeFree'] as bool? ?? true;
        }
        _mergeCouponUsageDates(uid, data, enriched);
      } catch (_) {}
      return _reconcileLifetimeAccess(enriched);
    }

    try {
      final couponSnap = await _firestore.collection('coupons').doc(code).get();
      if (couponSnap.exists) {
        _mergeCouponUsageDates(uid, couponSnap.data() ?? {}, enriched);
      }
    } catch (_) {}

    return _reconcileLifetimeAccess(enriched);
  }

  static Map<String, dynamic> _reconcileLifetimeAccess(
    Map<String, dynamic> enriched,
  ) {
    if (enriched['subscriptionExpiresAt'] is Timestamp) {
      enriched['lifetimeAccess'] = false;
    }
    return enriched;
  }

  static void _mergeCouponUsageDates(
    String uid,
    Map<String, dynamic> couponData,
    Map<String, dynamic> enriched,
  ) {
    final lastUsedBy = (couponData['lastUsedBy'] ?? '').toString().trim();
    if (lastUsedBy == uid && enriched['couponAppliedAt'] == null) {
      final lastUsedAt = couponData['lastUsedAt'];
      if (lastUsedAt is Timestamp) {
        enriched['couponAppliedAt'] = lastUsedAt;
      }
    }

    if (enriched['subscriptionExpiresAt'] == null) {
      final benefitExpiresAt = couponData['benefitExpiresAt'];
      if (benefitExpiresAt is Timestamp) {
        enriched['subscriptionExpiresAt'] = benefitExpiresAt;
      }
    }
  }

  static Future<_SubscriptionContext> _resolveContext(String uid) async {
    final userDoc = await _firestore.collection('users').doc(uid).get();
    final userData = userDoc.data() ?? {};
    final type = (userData['type'] ?? 'public').toString().trim().toLowerCase();

    if (type == 'work') {
      final companyId = (userData['companyId'] ?? '').toString();
      if (companyId.isEmpty) {
        return _SubscriptionContext(
          registerType: type,
          canManage: false,
          subscription: _subscriptionFrom(userData),
          userRef: null,
          companyRef: null,
        );
      }
      try {
        final companyDoc =
            await _firestore.collection('companies').doc(companyId).get();
        return _SubscriptionContext(
          registerType: 'company',
          canManage: false,
          subscription: _subscriptionFrom(companyDoc.data()),
          userRef: null,
          companyRef: null,
        );
      } catch (_) {
        return _SubscriptionContext(
          registerType: type,
          canManage: false,
          subscription: _subscriptionFrom(userData),
          userRef: null,
          companyRef: null,
        );
      }
    }

    DocumentSnapshot<Map<String, dynamic>>? companyDoc;
    try {
      companyDoc = await _firestore.collection('companies').doc(uid).get();
    } catch (_) {
      companyDoc = null;
    }
    final isCompanyAccount =
        type == 'company' || (companyDoc?.exists ?? false);

    if (isCompanyAccount) {
      final sub = companyDoc != null && companyDoc.exists
          ? _subscriptionFrom(companyDoc.data())
          : _subscriptionFrom(userData);
      return _SubscriptionContext(
        registerType: 'company',
        canManage: true,
        subscription: sub,
        userRef: _firestore.collection('users').doc(uid),
        companyRef: companyDoc != null && companyDoc.exists
            ? _firestore.collection('companies').doc(uid)
            : null,
      );
    }

    return _SubscriptionContext(
      registerType: 'public',
      canManage: true,
      subscription: _subscriptionFrom(userData),
      userRef: _firestore.collection('users').doc(uid),
      companyRef: null,
    );
  }

  static UserSubscriptionSnapshot _toSnapshot(_SubscriptionContext ctx) {
    final sub = ctx.subscription;
    final cancelledAt = sub['subscriptionCancelledAt'];
    return UserSubscriptionSnapshot(
      planId: _effectiveDisplayPlanId(sub),
      subscriptionStatus: sub['subscriptionStatus'] as String,
      couponCode: sub['couponCode']?.toString(),
      lifetimeAccess: sub['lifetimeAccess'] as bool,
      couponAppliedAt: _timestampToDate(sub['couponAppliedAt']),
      limitsEffectExpiresAt: _timestampToDate(sub['subscriptionExpiresAt']),
      registerType: ctx.registerType,
      canManage: ctx.canManage,
      cancelledAt: cancelledAt is Timestamp ? cancelledAt.toDate() : null,
    );
  }

  static Stream<UserSubscriptionSnapshot> watchCurrent() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const Stream.empty();
    }
    return _firestore
        .collection('users')
        .doc(uid)
        .snapshots()
        .asyncMap((_) async => loadCurrent());
  }

  static Future<UserSubscriptionSnapshot> loadCurrent() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const UserSubscriptionSnapshot(
        planId: 'free',
        subscriptionStatus: 'active',
        registerType: 'public',
        canManage: false,
      );
    }
    final ctx = await _resolveContext(uid);
    final subscription =
        await _enrichSubscriptionFromCouponUsage(uid, ctx.subscription);
    return _toSnapshot(_SubscriptionContext(
      registerType: ctx.registerType,
      canManage: ctx.canManage,
      subscription: subscription,
      userRef: ctx.userRef,
      companyRef: ctx.companyRef,
    ));
  }

  static Future<void> changePlan(String newPlanId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final ctx = await _resolveContext(uid);
    if (!ctx.canManage) {
      throw StateError(
        'Il piano è gestito dall\'amministratore dell\'azienda.',
      );
    }
    if (ctx.subscription['lifetimeAccess'] == true) {
      throw StateError(
        'Hai accesso lifetime tramite coupon: contatta assistenza per '
        'modificare il piano.',
      );
    }

    final currentPlan = _effectiveDisplayPlanId(ctx.subscription);
    if (currentPlan == newPlanId) return;

    if (SubscriptionBillingService.planUsesStripeCheckout(newPlanId)) {
      throw StateError(
        'I piani a pagamento si attivano tramite la pagina di pagamento Stripe.',
      );
    }

    final updates = <String, dynamic>{
      'subscriptionPlan': newPlanId,
      'subscriptionCancelledAt': FieldValue.delete(),
    };

    if (newPlanId == 'free') {
      updates['subscriptionStatus'] = 'active';
    } else {
      updates['subscriptionStatus'] = 'pending';
    }

    await _writeSubscription(ctx, updates);

    if (ctx.companyRef != null) {
      final companyCode = await _resolveCompanyCode(ctx);
      if (companyCode.isNotEmpty) {
        await CompanyCollaboratorLimitService.syncPlanLimitForCompany(
          companyId: ctx.companyRef!.id,
          companyCode: companyCode,
          subscriptionPlan: newPlanId,
        );
      }
    }
  }

  static Future<void> cancelSubscription() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final ctx = await _resolveContext(uid);
    if (!ctx.canManage) {
      throw StateError(
        'Il piano è gestito dall\'amministratore dell\'azienda.',
      );
    }
    if (ctx.subscription['lifetimeAccess'] == true) {
      throw StateError('L\'accesso lifetime non prevede annullamento.');
    }
    final plan = ctx.subscription['subscriptionPlan'] as String;
    if (plan == 'free') {
      throw StateError('Il piano gratuito non ha un abbonamento da annullare.');
    }

    if (SubscriptionBillingService.planUsesStripeCheckout(plan)) {
      await SubscriptionBillingService.openCustomerPortal();
      return;
    }

    await _writeSubscription(ctx, {
      'subscriptionStatus': 'cancelled',
      'subscriptionCancelledAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> _writeSubscription(
    _SubscriptionContext ctx,
    Map<String, dynamic> updates,
  ) async {
    final batch = _firestore.batch();
    if (ctx.userRef != null) {
      batch.update(ctx.userRef!, updates);
    }
    if (ctx.companyRef != null) {
      batch.update(ctx.companyRef!, updates);
    }
    await batch.commit();
  }

  static DateTime? _timestampToDate(dynamic value) =>
      value is Timestamp ? value.toDate() : null;

  /// Abbonamento utente con date/scadenza coupon da documento `coupons/{codice}`.
  static Future<Map<String, dynamic>> loadEnrichedSubscription(
    String uid,
  ) async {
    final ctx = await _resolveContext(uid);
    return _enrichSubscriptionFromCouponUsage(uid, ctx.subscription);
  }

  /// Piano effettivo per limiti e UI dopo scadenza effetto coupon.
  static String effectivePlanIdForLimits(Map<String, dynamic> subscription) {
    return _effectiveDisplayPlanId(subscription);
  }

  /// Coupon con limiti Enterprise/fair use ancora attivo.
  static bool isCouponBenefitActive(Map<String, dynamic> subscription) {
    final sub = _reconcileLifetimeAccess(Map<String, dynamic>.from(subscription));
    final code = (sub['couponCode'] ?? '').toString().trim();
    if (code.isEmpty) return false;

    final expires = sub['subscriptionExpiresAt'];
    if (expires is Timestamp) {
      return !expires.toDate().isBefore(DateTime.now());
    }
    return sub['lifetimeAccess'] == true;
  }

  /// Allinea il piano mostrato a quello usato per i limiti dopo scadenza effetto.
  static String _effectiveDisplayPlanId(Map<String, dynamic> sub) {
    var planId = (sub['subscriptionPlan'] ?? 'free').toString();
    final expires = sub['subscriptionExpiresAt'];
    if (expires is Timestamp && expires.toDate().isBefore(DateTime.now())) {
      planId = 'free';
    }
    return planId;
  }

  static Future<String> _resolveCompanyCode(_SubscriptionContext ctx) async {
    if (ctx.companyRef == null) return '';
    try {
      final snap = await ctx.companyRef!.get();
      final data = snap.data() ?? {};
      final code = (data['companyCode'] ?? data['userCode'] ?? '').toString();
      return code.trim();
    } catch (_) {
      return '';
    }
  }
}

class _SubscriptionContext {
  final String registerType;
  final bool canManage;
  final Map<String, dynamic> subscription;
  final DocumentReference<Map<String, dynamic>>? userRef;
  final DocumentReference<Map<String, dynamic>>? companyRef;

  const _SubscriptionContext({
    required this.registerType,
    required this.canManage,
    required this.subscription,
    required this.userRef,
    required this.companyRef,
  });
}
