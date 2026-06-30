import 'package:credit_calc_core/credit_calc_core.dart';

import 'bk_admin_service.dart';

/// Compatibilità: delega al servizio condiviso in credit_calc_core.
abstract final class PlanLimitsAdminService {
  static Future<void> savePlans(Map<String, Map<String, dynamic>> plans) {
    return PublicPlanLimitsAdminService.savePlans(
      plans,
      verifyAdmin: BkAdminService.isAdmin,
    );
  }
}
