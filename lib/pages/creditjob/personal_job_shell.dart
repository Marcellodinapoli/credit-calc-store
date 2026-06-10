import 'package:flutter/material.dart';

import '../../core/job_theme.dart';
import '../../core/maintenance_service.dart';
import '../../ui/layout/page_shell.dart';
import '../../widgets/maintenance_section_gate.dart';

/// Layout secondario per pagine CreditJob (tema verde sul contenuto).
class PersonalJobShell extends StatelessWidget {
  final String pageTitle;
  final Widget body;
  final Widget? bottomBar;
  final bool padded;

  const PersonalJobShell({
    super.key,
    required this.pageTitle,
    required this.body,
    this.bottomBar,
    this.padded = true,
  });

  @override
  Widget build(BuildContext context) {
    return SecondaryPageScaffold(
      pageTitle: pageTitle,
      project: BrandedPageProject.job,
      padded: padded,
      bottomBar: bottomBar == null
          ? null
          : Theme(data: buildJobTheme(), child: bottomBar!),
      body: MaintenanceSectionGate(
        sectionName: MaintenanceService.creditJob,
        child: Theme(
          data: buildJobTheme(),
          child: body,
        ),
      ),
    );
  }
}
