import 'package:credit_calc_core/credit_calc_core.dart';
import 'package:flutter/material.dart';

import '../../core/admin/bk_admin_service.dart';
import '../area/personal_area_shell.dart';

/// Backoffice app — wrapper su editor condiviso in credit_calc_core.
class BkPlanLimitsPage extends StatelessWidget {
  const BkPlanLimitsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return PersonalAreaShell(
      pageTitle: 'Piani FREE / PLUS / ENTERPRISE',
      body: PublicPlanLimitsAdminBody(
        verifyAdmin: BkAdminService.isAdmin,
      ),
    );
  }
}
