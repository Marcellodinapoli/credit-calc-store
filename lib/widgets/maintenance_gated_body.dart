import 'package:flutter/material.dart';

import '../core/maintenance_service.dart';
import 'maintenance_blocked_view.dart';

/// Sostituisce il body con [MaintenanceBlockedView] — come ImpaginazionePrincipale.
class MaintenanceGatedBody extends StatelessWidget {
  final String sectionName;
  final Widget child;

  const MaintenanceGatedBody({
    super.key,
    required this.sectionName,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Map<String, dynamic>?>(
      valueListenable: MaintenanceService.data,
      builder: (context, payload, _) {
        if (MaintenanceService.isSectionBlocked(payload, sectionName)) {
          return MaintenanceBlockedView(sectionName: sectionName);
        }
        return child;
      },
    );
  }
}
