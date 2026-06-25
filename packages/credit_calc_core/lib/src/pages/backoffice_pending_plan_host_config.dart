import 'package:flutter/material.dart';

/// Parametri per aprire l'editor piano da riscontro backoffice.
class BackofficePlanEditorRequest {
  const BackofficePlanEditorRequest({
    required this.pendingPlanId,
    required this.initialFormData,
    required this.skipInitialUsageGuard,
    required this.autoOpenCommissionExport,
    required this.initialCommissionDocIds,
    required this.initialCompanyName,
  });

  final String pendingPlanId;
  final Map<String, dynamic>? initialFormData;
  final bool skipInitialUsageGuard;
  final bool autoOpenCommissionExport;
  final List<String> initialCommissionDocIds;
  final String? initialCompanyName;
}

/// Hook host (Planet) per riscontro backoffice.
abstract final class BackofficePendingPlanHostConfig {
  BackofficePendingPlanHostConfig._();

  /// Es. migrazione IndexedDB prima di aprire un piano su Planet web.
  static Future<void> Function()? ensureDataReady;

  /// Sostituisce [StandardRepaymentPlanPage] core se impostato dall'host.
  static Widget Function(BackofficePlanEditorRequest request)?
      buildRepaymentPlanPage;

  /// Sostituisce [BalanceWriteOffPage] core se impostato dall'host.
  static Widget Function(BackofficePlanEditorRequest request)?
      buildBalanceWriteOffPage;
}
