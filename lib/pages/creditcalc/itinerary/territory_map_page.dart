import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../models/field_visit.dart';
import '../../../services/field_visit_service.dart';
import '../../../utils/field_visit_maps_util.dart';
import '../../../utils/map_marker_cluster_util.dart';
import '../../../widgets/visit_practice_links.dart';
import 'itinerary_page_shell.dart';

enum _MapPeriodFilter { today, week, all }

class TerritoryMapPage extends StatefulWidget {
  const TerritoryMapPage({
    super.key,
    this.personalArea = false,
    this.day,
    this.pageTitle = 'Mappa territorio',
  });

  final bool personalArea;
  final DateTime? day;
  final String pageTitle;

  @override
  State<TerritoryMapPage> createState() => _TerritoryMapPageState();
}

class _TerritoryMapPageState extends State<TerritoryMapPage> {
  final MapController _mapController = MapController();
  FieldVisit? _selected;
  double _zoom = 11;
  _MapPeriodFilter _period = _MapPeriodFilter.today;
  bool _plannedOnly = false;
  String? _creditorFilter;

  ItineraryPageShell get _shell =>
      ItineraryPageShell(personalArea: widget.personalArea);

  Future<void> _openExternalMaps(FieldVisit visit) async {
    if (!visit.hasCoordinates) return;
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=${visit.latitude},${visit.longitude}',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  LatLng _centerFor(List<FieldVisit> visits) {
    if (visits.isEmpty) return const LatLng(41.9028, 12.4964);
    final lat =
        visits.map((v) => v.latitude!).reduce((a, b) => a + b) / visits.length;
    final lng =
        visits.map((v) => v.longitude!).reduce((a, b) => a + b) / visits.length;
    return LatLng(lat, lng);
  }

  bool _isInWeek(DateTime scheduled) {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - 1));
    final end = start.add(const Duration(days: 7));
    return !scheduled.isBefore(start) && scheduled.isBefore(end);
  }

  bool _isToday(DateTime scheduled) {
    final now = DateTime.now();
    return scheduled.year == now.year &&
        scheduled.month == now.month &&
        scheduled.day == now.day;
  }

  List<FieldVisit> _filterVisits(List<FieldVisit> raw) {
    var visits = raw
        .where(
          (v) => v.hasCoordinates && v.status != FieldVisitStatus.cancelled,
        )
        .toList();

    if (widget.day == null) {
      visits = visits.where((v) {
        return switch (_period) {
          _MapPeriodFilter.today => _isToday(v.scheduledAt),
          _MapPeriodFilter.week => _isInWeek(v.scheduledAt),
          _MapPeriodFilter.all => true,
        };
      }).toList();
    }

    if (_plannedOnly) {
      visits =
          visits.where((v) => v.status == FieldVisitStatus.planned).toList();
    }

    final creditor = _creditorFilter?.trim();
    if (creditor != null && creditor.isNotEmpty) {
      visits = visits.where((v) => v.creditorName == creditor).toList();
    }

    visits.sort((a, b) {
      final orderA = a.routeOrder ?? 9999;
      final orderB = b.routeOrder ?? 9999;
      if (orderA != orderB) return orderA.compareTo(orderB);
      return a.scheduledAt.compareTo(b.scheduledAt);
    });

    return visits;
  }

  List<String> _creditorOptions(List<FieldVisit> raw) {
    final names = <String>{};
    for (final visit in raw) {
      final name = visit.creditorName?.trim();
      if (name != null && name.isNotEmpty) names.add(name);
    }
    final sorted = names.toList()..sort();
    return sorted;
  }

  Widget _buildFilters(List<FieldVisit> raw) {
    final creditors = _creditorOptions(raw);
    final children = <Widget>[];

    if (widget.day == null) {
      children.add(
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            ChoiceChip(
              label: const Text('Oggi'),
              selected: _period == _MapPeriodFilter.today,
              onSelected: (_) => setState(() {
                _period = _MapPeriodFilter.today;
                _selected = null;
              }),
            ),
            ChoiceChip(
              label: const Text('Settimana'),
              selected: _period == _MapPeriodFilter.week,
              onSelected: (_) => setState(() {
                _period = _MapPeriodFilter.week;
                _selected = null;
              }),
            ),
            ChoiceChip(
              label: const Text('Tutte'),
              selected: _period == _MapPeriodFilter.all,
              onSelected: (_) => setState(() {
                _period = _MapPeriodFilter.all;
                _selected = null;
              }),
            ),
          ],
        ),
      );
    }

    children.add(
      FilterChip(
        label: const Text('Solo in programma'),
        selected: _plannedOnly,
        onSelected: (value) => setState(() {
          _plannedOnly = value;
          _selected = null;
        }),
      ),
    );

    if (creditors.length > 1) {
      children.add(
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: DropdownButtonFormField<String?>(
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Creditore',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            value: _creditorFilter,
            items: [
              const DropdownMenuItem(value: null, child: Text('Tutti')),
              for (final name in creditors)
                DropdownMenuItem(value: name, child: Text(name)),
            ],
            onChanged: (value) => setState(() {
              _creditorFilter = value;
              _selected = null;
            }),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }

  @override
  Widget build(BuildContext context) {
    final day = widget.day;

    return _shell.secondary(
      pageTitle: widget.pageTitle,
      body: StreamBuilder<List<FieldVisit>>(
        stream: day != null
            ? FieldVisitService.watchWithCoordinates(day: day)
            : FieldVisitService.watchAllForUser(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final raw = snapshot.data ?? [];
          final visits = _filterVisits(raw);
          final center = _centerFor(visits);
          final clusters = clusterFieldVisits(visits, zoom: _zoom);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      day == null
                          ? 'Visite geolocalizzate (${visits.length})'
                          : 'Visite del ${_formatDay(day)} (${visits.length})',
                      style: const TextStyle(color: Colors.black54),
                    ),
                    const SizedBox(height: 8),
                    _buildFilters(raw),
                    if (FieldVisitMapsUtil.routableVisits(visits).length >= 2)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: OutlinedButton.icon(
                            onPressed: () =>
                                FieldVisitMapsUtil.openDayRoute(visits),
                            icon: const Icon(Icons.directions),
                            label: const Text('Apri percorso giornata'),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: visits.isEmpty
                        ? Container(
                            color: const Color(0xFFECEFF1),
                            alignment: Alignment.center,
                            child: const Text(
                              'Nessuna visita con indirizzo geolocalizzato.\n'
                              'Aggiungi visite in agenda con un indirizzo.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.black54),
                            ),
                          )
                        : FlutterMap(
                            mapController: _mapController,
                            options: MapOptions(
                              initialCenter: center,
                              initialZoom: visits.length == 1 ? 14 : 11,
                              onTap: (_, __) => setState(() => _selected = null),
                              onPositionChanged: (position, _) {
                                final nextZoom = position.zoom;
                                if ((nextZoom - _zoom).abs() > 0.2) {
                                  setState(() => _zoom = nextZoom);
                                }
                              },
                            ),
                            children: [
                              TileLayer(
                                urlTemplate:
                                    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                userAgentPackageName: 'it.creditcore.creditcalc',
                              ),
                              MarkerLayer(
                                markers: [
                                  for (final cluster in clusters)
                                    Marker(
                                      point: cluster.center,
                                      width: cluster.isSingle ? 44 : 48,
                                      height: cluster.isSingle ? 44 : 48,
                                      child: GestureDetector(
                                        onTap: () {
                                          if (cluster.isSingle) {
                                            setState(
                                              () => _selected = cluster.visits.first,
                                            );
                                            return;
                                          }
                                          _mapController.move(
                                            cluster.center,
                                            (_zoom + 2).clamp(11, 16),
                                          );
                                          setState(() {
                                            _zoom = (_zoom + 2).clamp(11, 16);
                                            _selected = null;
                                          });
                                        },
                                        child: cluster.isSingle
                                            ? Icon(
                                                Icons.location_on,
                                                size: 40,
                                                color: _selected?.id ==
                                                        cluster.visits.first.id
                                                    ? Colors.orange
                                                    : cluster.visits.first.status ==
                                                            FieldVisitStatus
                                                                .completed
                                                        ? Colors.green
                                                        : const Color(
                                                            0xFF00B0FF,
                                                          ),
                                              )
                                            : Container(
                                                alignment: Alignment.center,
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFF00B0FF),
                                                  shape: BoxShape.circle,
                                                  border: Border.all(
                                                    color: Colors.white,
                                                    width: 2,
                                                  ),
                                                ),
                                                child: Text(
                                                  '${cluster.count}',
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.w700,
                                                    fontSize: 14,
                                                  ),
                                                ),
                                              ),
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                  ),
                ),
              ),
              if (_selected != null)
                Card(
                  margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _selected!.companyName,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (_selected!.address.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(_selected!.address),
                        ],
                        const SizedBox(height: 8),
                        Text(
                          fieldVisitStatusLabel(_selected!.status),
                          style: const TextStyle(color: Colors.black54),
                        ),
                        VisitPracticeLinks(visit: _selected!),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: () => _openExternalMaps(_selected!),
                          icon: const Icon(Icons.directions),
                          label: const Text('Apri in mappe'),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  String _formatDay(DateTime day) {
    final d = day.day.toString().padLeft(2, '0');
    final m = day.month.toString().padLeft(2, '0');
    return '$d/$m/${day.year}';
  }
}
