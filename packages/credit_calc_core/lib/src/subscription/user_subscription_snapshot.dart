import 'subscription_plan_options.dart';

/// Stato abbonamento letto da Firestore (utente o azienda).
class UserSubscriptionSnapshot {
  final String planId;
  final String subscriptionStatus;
  final String? couponCode;
  final bool lifetimeAccess;
  final String registerType;
  final bool canManage;
  final DateTime? cancelledAt;

  const UserSubscriptionSnapshot({
    required this.planId,
    required this.subscriptionStatus,
    this.couponCode,
    this.lifetimeAccess = false,
    required this.registerType,
    required this.canManage,
    this.cancelledAt,
  });

  bool get isFree => planId == 'free';
  bool get isCancelled => subscriptionStatus == 'cancelled';
  bool get isPending => subscriptionStatus == 'pending';
  bool get isActive => subscriptionStatus == 'active';

  bool get hasCoupon =>
      couponCode != null && couponCode!.trim().isNotEmpty;

  bool get canCancel =>
      canManage &&
      !lifetimeAccess &&
      !isFree &&
      !isCancelled;

  bool get canChangePlan => canManage && !lifetimeAccess;

  String get statusLabel {
    if (lifetimeAccess) return 'Attivo (coupon lifetime)';
    return switch (subscriptionStatus) {
      'cancelled' => 'Abbonamento annullato',
      'pending' => 'In attesa di attivazione',
      'active' => 'Attivo',
      _ => subscriptionStatus,
    };
  }

  SubscriptionPlanOption? planOption(List<SubscriptionPlanOption> plans) {
    for (final plan in plans) {
      if (plan.id == planId) return plan;
    }
    return null;
  }
}
