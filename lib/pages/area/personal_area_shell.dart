import 'package:flutter/material.dart';

import '../../core/maintenance_service.dart';
import '../../ui/layout/page_shell.dart';
import '../../widgets/maintenance_section_gate.dart';

/// Layout secondario per pagine Area personale (titolo + indietro).
class PersonalAreaShell extends StatelessWidget {
  final String pageTitle;
  final Widget body;
  final Widget? bottomBar;
  final bool bypassMaintenance;
  final String maintenanceSection;

  const PersonalAreaShell({
    super.key,
    required this.pageTitle,
    required this.body,
    this.bottomBar,
    this.bypassMaintenance = false,
    this.maintenanceSection = MaintenanceService.area,
  });

  @override
  Widget build(BuildContext context) {
    return SecondaryPageScaffold(
      pageTitle: pageTitle,
      project: BrandedPageProject.area,
      bottomBar: bottomBar,
      body: MaintenanceSectionGate(
        sectionName: maintenanceSection,
        enabled: !bypassMaintenance,
        child: body,
      ),
    );
  }
}
