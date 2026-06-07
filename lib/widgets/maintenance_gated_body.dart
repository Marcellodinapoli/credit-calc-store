import 'package:cloud_firestore/cloud_firestore.dart';
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
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: MaintenanceService.watch(),
      builder: (context, snap) {
        final payload = MaintenanceService.dataFrom(snap.data);
        if (MaintenanceService.isSectionBlocked(payload, sectionName)) {
          return MaintenanceBlockedView(sectionName: sectionName);
        }
        return child;
      },
    );
  }
}
