import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../core/maintenance_service.dart';
import 'maintenance_blocked_view.dart';

/// Mostra [MaintenanceBlockedView] quando la sezione è in manutenzione su Firestore.
class MaintenanceSectionGate extends StatelessWidget {
  final String sectionName;
  final Widget child;
  final bool enabled;

  const MaintenanceSectionGate({
    super.key,
    required this.sectionName,
    required this.child,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: MaintenanceService.watch(),
      builder: (context, snapshot) {
        final data = MaintenanceService.dataFrom(snapshot.data);
        if (MaintenanceService.isSectionBlocked(data, sectionName)) {
          return MaintenanceBlockedView(sectionName: sectionName);
        }
        return child;
      },
    );
  }
}
