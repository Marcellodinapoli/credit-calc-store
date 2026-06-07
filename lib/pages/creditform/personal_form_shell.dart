import 'package:flutter/material.dart';

import '../../core/form_theme.dart';
import '../../core/maintenance_service.dart';
import '../../ui/layout/page_shell.dart';
import '../../widgets/maintenance_section_gate.dart';

class PersonalFormShell extends StatelessWidget {
  final String pageTitle;
  final Widget body;
  final Widget? bottomBar;
  final bool padded;

  const PersonalFormShell({
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
      padded: padded,
      bottomBar: bottomBar == null
          ? null
          : Theme(data: buildFormTheme(), child: bottomBar!),
      body: MaintenanceSectionGate(
        sectionName: MaintenanceService.creditForm,
        child: Theme(
          data: buildFormTheme(),
          child: body,
        ),
      ),
    );
  }
}
