import 'package:flutter/material.dart';

/// Dati per programmare una visita da un incasso in elenco provvigioni.
class CommissionCollectionVisitRequest {
  const CommissionCollectionVisitRequest({
    required this.entryData,
    required this.entryId,
    required this.initialDay,
  });

  final Map<String, dynamic> entryData;
  final String entryId;
  final DateTime initialDay;
}

/// Hook host (Planet) per azioni non incluse nel pacchetto core.
abstract final class CommissionCollectionsHostConfig {
  CommissionCollectionsHostConfig._();

  /// Es. dialog agenda itinerario su Planet web.
  static Future<void> Function(
    BuildContext context,
    CommissionCollectionVisitRequest request,
  )? scheduleFieldVisit;
}
