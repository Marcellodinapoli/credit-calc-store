import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../models/field_visit.dart';
import '../utils/field_visit_route_optimizer.dart';

const _routeBlue = Color(0xFF1565C0);
const _originGreen = Color(0xFF2E7D32);

Future<bool> showFieldVisitRoutePreviewDialog(
  BuildContext context, {
  required FieldVisitRoutePlan plan,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => _FieldVisitRoutePreviewDialog(plan: plan),
  );
  return result == true;
}

class _FieldVisitRoutePreviewDialog extends StatefulWidget {
  const _FieldVisitRoutePreviewDialog({required this.plan});

  final FieldVisitRoutePlan plan;

  @override
  State<_FieldVisitRoutePreviewDialog> createState() =>
      _FieldVisitRoutePreviewDialogState();
}

class _FieldVisitRoutePreviewDialogState
    extends State<_FieldVisitRoutePreviewDialog> {
  final MapController _mapController = MapController();

  bool get _hasGpsOrigin =>
      widget.plan.usedGpsOrigin &&
      widget.plan.originLatitude != null &&
      widget.plan.originLongitude != null;

  List<FieldVisit> get _mappedVisits => widget.plan.orderedVisits
      .where((v) => v.hasCoordinates)
      .toList();

  List<FieldVisit> get _unmappedVisits => widget.plan.orderedVisits
      .where((v) => !v.hasCoordinates && v.address.trim().isNotEmpty)
      .toList();

  List<LatLng> get _routePoints {
    final points = <LatLng>[];
    if (_hasGpsOrigin) {
      points.add(
        LatLng(widget.plan.originLatitude!, widget.plan.originLongitude!),
      );
    }
    for (final visit in widget.plan.orderedVisits) {
      if (visit.hasCoordinates) {
        points.add(LatLng(visit.latitude!, visit.longitude!));
      }
    }
    return points;
  }

  LatLng _initialCenter() {
    final points = _routePoints;
    if (points.isEmpty) return const LatLng(41.9028, 12.4964);
    final lat = points.map((p) => p.latitude).reduce((a, b) => a + b) /
        points.length;
    final lng = points.map((p) => p.longitude).reduce((a, b) => a + b) /
        points.length;
    return LatLng(lat, lng);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _fitRouteBounds());
  }

  void _fitRouteBounds() {
    final points = _routePoints;
    if (points.length < 2) return;

    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: LatLngBounds.fromPoints(points),
        padding: const EdgeInsets.all(36),
      ),
    );
  }

  String _visitLabel(FieldVisit visit) {
    final company = visit.companyName.trim();
    return company.isEmpty ? 'Visita' : company;
  }

  @override
  Widget build(BuildContext context) {
    final routePoints = _routePoints;
    final mapHeight = MediaQuery.sizeOf(context).width >= 520 ? 320.0 : 260.0;

    return AlertDialog(
      title: const Text('Anteprima percorso'),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Tutte le tappe con posizione sono numerate sulla mappa.',
              style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                height: mapHeight,
                child: routePoints.isEmpty
                    ? ColoredBox(
                        color: const Color(0xFFECEFF1),
                        child: Center(
                          child: Text(
                            'Nessuna tappa geolocalizzata.\n'
                            'Il percorso userà gli indirizzi testuali.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey.shade700),
                          ),
                        ),
                      )
                    : FlutterMap(
                        mapController: _mapController,
                        options: MapOptions(
                          initialCenter: _initialCenter(),
                          initialZoom: routePoints.length == 1 ? 14 : 11,
                          interactionOptions: const InteractionOptions(
                            flags: InteractiveFlag.all,
                          ),
                        ),
                        children: [
                          TileLayer(
                            urlTemplate:
                                'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: 'it.creditcore.creditcalc',
                          ),
                          if (routePoints.length > 1)
                            PolylineLayer(
                              polylines: [
                                Polyline(
                                  points: routePoints,
                                  color: _routeBlue,
                                  strokeWidth: 4,
                                ),
                              ],
                            ),
                          MarkerLayer(
                            markers: [
                              if (_hasGpsOrigin)
                                Marker(
                                  point: LatLng(
                                    widget.plan.originLatitude!,
                                    widget.plan.originLongitude!,
                                  ),
                                  width: 40,
                                  height: 40,
                                  child: const Icon(
                                    Icons.my_location,
                                    color: _originGreen,
                                    size: 34,
                                  ),
                                ),
                              for (var i = 0; i < _mappedVisits.length; i++)
                                Marker(
                                  point: LatLng(
                                    _mappedVisits[i].latitude!,
                                    _mappedVisits[i].longitude!,
                                  ),
                                  width: 36,
                                  height: 36,
                                  child: _numberedMarker('${i + 1}'),
                                ),
                            ],
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                if (_hasGpsOrigin) _legendChip(Icons.my_location, 'Partenza'),
                _legendChip(Icons.circle, 'Tappe numerate', color: _routeBlue),
                if (_unmappedVisits.isNotEmpty)
                  _legendChip(
                    Icons.location_off_outlined,
                    'Solo indirizzo',
                    color: Colors.orange.shade800,
                  ),
              ],
            ),
            if (_unmappedVisits.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Non sulla mappa: ${_unmappedVisits.map(_visitLabel).join(', ')}',
                style: TextStyle(fontSize: 12, color: Colors.orange.shade900),
              ),
            ],
            if (widget.plan.excludedFromMaps.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Google Maps aprirà al massimo 10 tappe: '
                '${widget.plan.excludedFromMaps.length} restano fuori.',
                style: TextStyle(fontSize: 12, color: Colors.orange.shade900),
              ),
            ],
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
          label: const Text('Apri Google Maps'),
        ),
      ],
    );
  }

  Widget _numberedMarker(String label) {
    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: _routeBlue,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: 14,
        ),
      ),
    );
  }

  Widget _legendChip(IconData icon, String label, {Color? color}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color ?? Colors.black54),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}
