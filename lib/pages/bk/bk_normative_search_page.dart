import 'package:credit_calc_core/credit_calc_core.dart';
import 'package:flutter/material.dart';

import '../../core/admin/bk_admin_service.dart';
import '../area/personal_area_shell.dart';

/// Backoffice app — prompt AI Ricerca normativa.
class BkNormativeSearchPage extends StatelessWidget {
  const BkNormativeSearchPage({super.key});

  @override
  Widget build(BuildContext context) {
    return PersonalAreaShell(
      pageTitle: 'Prompt ricerca normativa',
      showAccountMenu: false,
      body: NormativeSearchAdminBody(
        verifyAdmin: BkAdminService.isAdmin,
      ),
    );
  }
}
