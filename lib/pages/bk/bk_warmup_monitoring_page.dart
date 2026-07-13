import 'package:credit_calc_core/credit_calc_core.dart';
import 'package:flutter/material.dart';

import '../../core/admin/bk_admin_service.dart';
import '../area/personal_area_shell.dart';

/// Backoffice — monitoraggio warm-up telefonata e contestazioni.
class BkWarmupMonitoringPage extends StatelessWidget {
  const BkWarmupMonitoringPage({super.key});

  @override
  Widget build(BuildContext context) {
    return PersonalAreaShell(
      pageTitle: 'Warm-up telefonata e contestazioni',
      showAccountMenu: false,
      body: WarmupMonitoringAdminBody(
        verifyAdmin: BkAdminService.isAdmin,
      ),
    );
  }
}
