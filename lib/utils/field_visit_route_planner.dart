import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/field_visit.dart';
import '../services/field_visit_service.dart';
import '../services/location_consent_service.dart';
import '../services/user_location_service.dart';
import '../widgets/field_visit_route_preview_dialog.dart';
import 'field_visit_maps_util.dart';
import 'field_visit_route_optimizer.dart';

abstract final class FieldVisitRoutePlanner {
  static Future<void> planAndOpen(
    BuildContext context,
    List<FieldVisit> visits,
  ) async {
    final routable = FieldVisitMapsUtil.routableVisits(visits);
    if (routable.isEmpty) {
      _showSnack(
        context,
        'Aggiungi almeno una visita con indirizzo o posizione.',
      );
      return;
    }
    if (routable.length < 2 && !routable.first.hasCoordinates) {
      _showSnack(
        context,
        'Servono almeno 2 visite con indirizzo per aprire il percorso.',
      );
      return;
    }

    if (!context.mounted) return;
    final mode = await showDialog<RoutePlanMode>(
      context: context,
      builder: (ctx) => const _RouteModeDialog(),
    );
    if (mode == null || !context.mounted) return;

    final uid = FirebaseAuth.instance.currentUser?.uid;
    final hasLocationConsent =
        uid != null && await LocationConsentService.loadEnabled(uid);
    final canReadGps =
        mode == RoutePlanMode.byDistance && hasLocationConsent;

    ({double lat, double lng})? location;
    if (canReadGps) {
      if (!context.mounted) return;
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Expanded(child: Text('Rilevo la tua posizione...')),
            ],
          ),
        ),
      );

      location = await getCurrentUserLocation();
      if (context.mounted) Navigator.pop(context);
    }

    final plan = FieldVisitRouteOptimizer.buildPlan(
      visits,
      mode: mode,
      originLatitude: location?.lat,
      originLongitude: location?.lng,
    );

    if (plan.orderedVisits.isEmpty) {
      if (!context.mounted) return;
      _showSnack(context, 'Nessuna visita disponibile per il percorso.');
      return;
    }

    if (!context.mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => _RoutePlanDialog(plan: plan),
    );
    if (confirmed != true || !context.mounted) return;

    await FieldVisitService.saveRouteOrder(plan.orderedVisits);

    if (!context.mounted) return;
    final openMaps = await showFieldVisitRoutePreviewDialog(
      context,
      plan: plan,
    );
    if (!openMaps || !context.mounted) return;

    final opened = await FieldVisitMapsUtil.openDayRoute(
      plan.orderedVisits,
      originLatitude: plan.originLatitude,
      originLongitude: plan.originLongitude,
    );

    if (!context.mounted) return;
    if (!opened) {
      _showSnack(context, 'Impossibile aprire Google Maps.');
      return;
    }

    if (plan.excludedFromMaps.isNotEmpty) {
      _showSnack(
        context,
        'Google Maps supporta al massimo 10 tappe: '
        '${plan.excludedFromMaps.length} visite restano fuori dal link.',
      );
    }
  }

  static void _showSnack(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}

class _RouteModeDialog extends StatelessWidget {
  const _RouteModeDialog();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Modalità percorso'),
      content: const Text(
        'Scegli come ordinare le visite della giornata.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annulla'),
        ),
        OutlinedButton.icon(
          onPressed: () => Navigator.pop(context, RoutePlanMode.bySchedule),
          icon: const Icon(Icons.schedule),
          label: const Text('Rispetta gli orari'),
        ),
        FilledButton.icon(
          onPressed: () => Navigator.pop(context, RoutePlanMode.byDistance),
          icon: const Icon(Icons.route),
          label: const Text('Ottimizza i km'),
        ),
      ],
    );
  }
}

class _RoutePlanDialog extends StatelessWidget {
  const _RoutePlanDialog({required this.plan});

  final FieldVisitRoutePlan plan;

  String _formatTime(DateTime value) {
    final h = value.hour.toString().padLeft(2, '0');
    final m = value.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  Widget build(BuildContext context) {
    final subtitle = switch (plan.mode) {
      RoutePlanMode.bySchedule =>
        'Ordine basato sugli orari programmati in agenda.',
      RoutePlanMode.byDistance when plan.usedGpsOrigin =>
        'Partenza dalla tua posizione attuale, ordine ottimizzato per distanza.',
      RoutePlanMode.byDistance =>
        'Posizione non disponibile: ordine basato sugli orari programmati.',
    };

    return AlertDialog(
      title: const Text('Scaletta visite'),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              subtitle,
              style: const TextStyle(color: Colors.black54),
            ),
            if (plan.excludedFromMaps.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Le prime ${plan.orderedVisits.length} tappe verranno aperte '
                'in Google Maps.',
                style: TextStyle(
                  color: Colors.orange.shade900,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 360),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: plan.orderedVisits.length,
                separatorBuilder: (_, __) => const Divider(height: 12),
                itemBuilder: (context, index) {
                  final visit = plan.orderedVisits[index];
                  final distance =
                      FieldVisitRouteOptimizer.distanceFromPreviousKm(
                    plan,
                    index,
                  );
                  final company =
                      visit.companyName.isEmpty ? 'Visita' : visit.companyName;

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 14,
                        child: Text('${index + 1}'),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              company,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (visit.address.isNotEmpty)
                              Text(
                                visit.address,
                                style: const TextStyle(
                                  color: Colors.black54,
                                  fontSize: 13,
                                ),
                              ),
                            Text(
                              [
                                _formatTime(visit.scheduledAt),
                                if (distance != null)
                                  '~${distance.toStringAsFixed(1)} km',
                                if (visit.needsGeocoding) 'mappa non disponibile',
                              ].join(' · '),
                              style: const TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Annulla'),
        ),
        FilledButton.icon(
          onPressed: () => Navigator.pop(context, true),
          icon: const Icon(Icons.directions),
          label: const Text('Applica percorso'),
        ),
      ],
    );
  }
}
