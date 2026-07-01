import 'package:credit_calc_core/credit_calc_core.dart';

class RegistrationPlanOption {
  final String id;
  final String name;
  final String price;
  final String description;
  final bool availableNow;

  const RegistrationPlanOption({
    required this.id,
    required this.name,
    required this.price,
    required this.description,
    this.availableNow = true,
  });
}

List<RegistrationPlanOption> registrationPlansForType(String registerType) {
  if (registerType == 'company') {
    final free = companySubscriptionPlanForId('free')!;
    final starter = companySubscriptionPlanForId('plus')!;
    final enterprise = companySubscriptionPlanForId('enterprise')!;
    return [
      RegistrationPlanOption(
        id: 'free',
        name: free.name,
        price: free.price,
        description: free.description,
      ),
      RegistrationPlanOption(
        id: 'plus',
        name: starter.name,
        price: starter.price,
        description: starter.description,
        availableNow: false,
      ),
      RegistrationPlanOption(
        id: 'enterprise',
        name: enterprise.name,
        price: enterprise.price,
        description: enterprise.description,
        availableNow: false,
      ),
    ];
  }

  return [
    for (final plan in defaultPublicSubscriptionPlans())
      RegistrationPlanOption(
        id: plan.id,
        name: PublicPlanLimitsConfigService.publicPlanTierLabel(plan.id),
        price: plan.price,
        description: plan.description,
        availableNow: plan.id == 'free',
      ),
  ];
}
