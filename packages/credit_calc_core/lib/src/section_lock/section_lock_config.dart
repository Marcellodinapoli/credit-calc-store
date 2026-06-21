import '../subscription/public_plan_limits.dart';

/// Mappa chiavi sezione CreditCalc → metriche utilizzo piano public.
abstract final class SectionLockConfig {
  static PublicUsageMetric? metricFor(String sectionKey) => switch (sectionKey) {
        'repayment_plan' => PublicUsageMetric.repaymentPlan,
        'balance_write_off' => PublicUsageMetric.balanceWriteOff,
        _ => null,
      };
}
