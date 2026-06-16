import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'subscription_plan_options.dart';
import 'user_subscription_snapshot.dart';

/// Lettura e aggiornamento campi abbonamento su `users` / `companies`.
abstract final class UserSubscriptionService {
  static final _firestore = FirebaseFirestore.instance;

  static Map<String, dynamic> _subscriptionFrom(Map<String, dynamic>? data) {
    final map = data ?? {};
    return {
      'subscriptionPlan': (map['subscriptionPlan'] ?? 'free').toString(),
      'subscriptionStatus':
          (map['subscriptionStatus'] ?? 'active').toString(),
      'couponCode': map['couponCode'],
      'lifetimeAccess': map['lifetimeAccess'] == true,
      'subscriptionCancelledAt': map['subscriptionCancelledAt'],
    };
  }

  static Future<_SubscriptionContext> _resolveContext(String uid) async {
    final userDoc = await _firestore.collection('users').doc(uid).get();
    final userData = userDoc.data() ?? {};
    final type = (userData['type'] ?? 'public').toString();

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
      final companyDoc =
          await _firestore.collection('companies').doc(companyId).get();
      return _SubscriptionContext(
        registerType: 'company',
        canManage: false,
        subscription: _subscriptionFrom(companyDoc.data()),
        userRef: null,
        companyRef: null,
      );
    }

    if (type == 'company') {
      final companyDoc =
          await _firestore.collection('companies').doc(uid).get();
      final sub = companyDoc.exists
          ? _subscriptionFrom(companyDoc.data())
          : _subscriptionFrom(userData);
      return _SubscriptionContext(
        registerType: type,
        canManage: true,
        subscription: sub,
        userRef: _firestore.collection('users').doc(uid),
        companyRef: _firestore.collection('companies').doc(uid),
      );
    }

    return _SubscriptionContext(
      registerType: type,
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
      planId: sub['subscriptionPlan'] as String,
      subscriptionStatus: sub['subscriptionStatus'] as String,
      couponCode: sub['couponCode']?.toString(),
      lifetimeAccess: sub['lifetimeAccess'] as bool,
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
    return _toSnapshot(ctx);
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

    final currentPlan = ctx.subscription['subscriptionPlan'] as String;
    if (currentPlan == newPlanId) return;

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
