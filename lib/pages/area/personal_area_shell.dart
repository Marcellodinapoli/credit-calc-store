import 'package:flutter/material.dart';

import '../../core/maintenance_service.dart';
import '../../ui/layout/page_shell.dart';
import '../../widgets/gestione_menu_badge_marker.dart';
import '../../widgets/maintenance_section_gate.dart';
import '../../services/gestione_menu_badge_service.dart';

/// Layout secondario per pagine Area personale (titolo + indietro).
class PersonalAreaShell extends StatelessWidget {
  final String pageTitle;
  final Widget body;
  final Widget? bottomBar;
  final bool bypassMaintenance;
  final String maintenanceSection;
  final bool gestioneSection;
  final GestioneMenuBadgeKey? gestioneBadgeKey;

  const PersonalAreaShell({
    super.key,
    required this.pageTitle,
    required this.body,
    this.bottomBar,
    this.bypassMaintenance = false,
    this.maintenanceSection = MaintenanceService.area,
    this.gestioneSection = false,
    this.gestioneBadgeKey,
  });

  @override
  Widget build(BuildContext context) {
    return SecondaryPageScaffold(
      pageTitle: gestioneSection ? 'Gestione' : pageTitle,
      project: BrandedPageProject.area,
      bottomBar: bottomBar,
      body: GestioneMenuBadgeMarker(
        badgeKey: gestioneBadgeKey,
        child: MaintenanceSectionGate(
          sectionName: maintenanceSection,
          enabled: !bypassMaintenance,
          child: body,
        ),
      ),
    );
  }
}
