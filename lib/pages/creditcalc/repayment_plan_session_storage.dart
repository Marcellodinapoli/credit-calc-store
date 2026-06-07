import 'repayment_plan_session_storage_native.dart' as impl;

/// Mantiene gli ID incassi registrati in sessione (persistenza locale).
abstract final class RepaymentPlanSessionStorage {
  RepaymentPlanSessionStorage._();

  static Future<void> preload() => impl.preloadRepaymentPlanSessionStorage();

  static List<String> readIds() => impl.readRepaymentPlanCommissionDocIds();

  static void appendIds(List<String> ids) =>
      impl.appendRepaymentPlanCommissionDocIds(ids);

  static void clear() => impl.clearRepaymentPlanCommissionDocIds();
}
