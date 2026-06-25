import 'package:flutter/material.dart';

/// Dati per programmare un follow-up in agenda dopo export provvigioni.
class RepaymentPlanFollowUpRequest {
  const RepaymentPlanFollowUpRequest({
    required this.companyName,
    required this.creditorId,
    required this.creditorName,
    this.calculationId,
  });

  final String companyName;
  final String creditorId;
  final String creditorName;
  final String? calculationId;
}

/// Hook host (Planet) per funzioni non incluse nel pacchetto core.
abstract final class RepaymentPlanHostConfig {
  RepaymentPlanHostConfig._();

  /// Es. dialog «Programma visita» + agenda itinerario su Planet web.
  static Future<void> Function(
    BuildContext context,
    RepaymentPlanFollowUpRequest request,
  )? offerFollowUpVisit;
}
