import 'package:credit_calc_core/credit_calc_core.dart';
import 'package:flutter/material.dart';

import '../../core/admin/bk_admin_service.dart';
import '../area/personal_area_shell.dart';

/// Backoffice app — prompt AI Analisi telefonata.
class BkCallAnalysisPage extends StatelessWidget {
  const BkCallAnalysisPage({super.key});

  @override
  Widget build(BuildContext context) {
    return PersonalAreaShell(
      pageTitle: 'Prompt analisi telefonata',
      showAccountMenu: false,
      body: CallAnalysisAdminBody(
        verifyAdmin: BkAdminService.isAdmin,
      ),
    );
  }
}
