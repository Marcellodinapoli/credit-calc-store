import 'package:credit_calc_core/credit_calc_core.dart';
import 'package:flutter/material.dart';

import '../../core/admin/bk_admin_service.dart';
import '../area/personal_area_shell.dart';

/// Backoffice app — testi card descrittive ecosistema (CreditForm / Calc / Job).
class BkEcosystemSectionsPage extends StatelessWidget {
  const BkEcosystemSectionsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return PersonalAreaShell(
      pageTitle: 'Sezioni ecosistema',
      showAccountMenu: false,
      body: EcosystemSectionsAdminBody(
        verifyAdmin: BkAdminService.isAdmin,
      ),
    );
  }
}
