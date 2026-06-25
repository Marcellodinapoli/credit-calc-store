import 'repayment_plan_session_storage_stub.dart'
    if (dart.library.html) 'repayment_plan_session_storage_web.dart'
    if (dart.library.io) 'repayment_plan_session_storage_io.dart' as impl;

/// ID incassi registrati in sessione piano (sessionStorage web / prefs native).
abstract final class RepaymentPlanSessionStorage {
  RepaymentPlanSessionStorage._();

  static Future<void> preload() => impl.preloadRepaymentPlanSessionStorage();

  static List<String> readIds() => impl.readRepaymentPlanCommissionDocIds();

  static void appendIds(List<String> ids) =>
      impl.appendRepaymentPlanCommissionDocIds(ids);

  static void clear() => impl.clearRepaymentPlanCommissionDocIds();
}
