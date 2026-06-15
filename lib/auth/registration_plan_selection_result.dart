/// Esito scelta piano in registrazione (con coupon opzionale).
class RegistrationPlanSelectionResult {
  final String planId;
  final String? couponCode;
  final bool couponApplied;

  const RegistrationPlanSelectionResult({
    required this.planId,
    this.couponCode,
    this.couponApplied = false,
  });
}

String registrationPlanLabel(String? planId) {
  return switch (planId) {
    'plus' => 'Plus',
    'enterprise' => 'Enterprise',
    _ => 'Gratis',
  };
}
