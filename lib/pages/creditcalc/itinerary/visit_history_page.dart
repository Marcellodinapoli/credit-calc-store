import 'package:flutter/material.dart';

import '../../../core/theme/app_card_theme.dart';
import '../../../models/field_visit.dart';
import '../../../services/field_visit_service.dart';
import '../../../utils/visit_zone_util.dart';
import 'itinerary_page_shell.dart';

class VisitHistoryPage extends StatefulWidget {
  const VisitHistoryPage({super.key, this.personalArea = false});

  final bool personalArea;

  @override
  State<VisitHistoryPage> createState() => _VisitHistoryPageState();
}

class _VisitHistoryPageState extends State<VisitHistoryPage> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  String? _zoneFilter;

  ItineraryPageShell get _shell =>
      ItineraryPageShell(personalArea: widget.personalArea);

  List<FieldVisit> _filterByMonth(List<FieldVisit> visits) {
    return visits.where((v) {
      final d = v.scheduledAt;
      return d.year == _month.year && d.month == _month.month;
    }).toList();
  }

  Map<String, int> _zoneCounts(List<FieldVisit> visits) {
    final counts = <String, int>{};
    for (final visit in visits) {
      final zone = extractZoneFromAddress(visit.address) ?? 'Zona non indicata';
      counts[zone] = (counts[zone] ?? 0) + 1;
    }
    return counts;
  }

  Future<void> _pickMonth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _month,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      locale: const Locale('it', 'IT'),
    );
    if (picked != null) {
      setState(() {
        _month = DateTime(picked.year, picked.month);
        _zoneFilter = null;
      });
    }
  }

  String _formatMonth(DateTime month) {
    const names = [
      'Gennaio',
      'Febbraio',
      'Marzo',
      'Aprile',
      'Maggio',
      'Giugno',
      'Luglio',
      'Agosto',
      'Settembre',
      'Ottobre',
      'Novembre',
      'Dicembre',
    ];
    return '${names[month.month - 1]} ${month.year}';
  }

  String _formatDateTime(DateTime value) {
    final d = value.day.toString().padLeft(2, '0');
    final m = value.month.toString().padLeft(2, '0');
    final h = value.hour.toString().padLeft(2, '0');
    final min = value.minute.toString().padLeft(2, '0');
    return '$d/$m/${value.year} $h:$min';
  }

  @override
  Widget build(BuildContext context) {
    return _shell.secondary(
      pageTitle: 'Storico visite',
      body: StreamBuilder<List<FieldVisit>>(
        stream: FieldVisitService.watchAllForUser(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final all = snapshot.data ?? [];
          final monthVisits = _filterByMonth(all);
          final zones = _zoneCounts(monthVisits);
          final zoneNames = zones.keys.toList()..sort();

          var visible = monthVisits;
          if (_zoneFilter != null) {
            visible = monthVisits.where((v) {
              final zone =
                  extractZoneFromAddress(v.address) ?? 'Zona non indicata';
              return zone == _zoneFilter;
            }).toList();
          }

          visible.sort((a, b) => b.scheduledAt.compareTo(a.scheduledAt));

          final planned =
              monthVisits.where((v) => v.status == FieldVisitStatus.planned);
          final completed =
              monthVisits.where((v) => v.status == FieldVisitStatus.completed);
          final geolocated = monthVisits.where((v) => v.hasCoordinates);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Riepilogo mensile e filtro per zona territoriale.',
                      style: TextStyle(
                        color: Colors.black.withValues(alpha: 0.54),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: _pickMonth,
                          icon: const Icon(Icons.calendar_month),
                          label: Text(_formatMonth(_month)),
                        ),
                        if (_zoneFilter != null)
                          InputChip(
                            label: Text('Zona: $_zoneFilter'),
                            onDeleted: () => setState(() => _zoneFilter = null),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _statChip('Totale', '${monthVisits.length}'),
                        _statChip('Completate', '${completed.length}'),
                        _statChip('In programma', '${planned.length}'),
                        _statChip('Geolocalizzate', '${geolocated.length}'),
                        _statChip('Zone', '${zoneNames.length}'),
                      ],
                    ),
                    if (zoneNames.length > 1) ...[
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String?>(
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Filtra per zona',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        value: _zoneFilter,
                        items: [
                          const DropdownMenuItem(
                            value: null,
                            child: Text('Tutte le zone'),
                          ),
                          for (final zone in zoneNames)
                            DropdownMenuItem(
                              value: zone,
                              child: Text('$zone (${zones[zone]})'),
                            ),
                        ],
                        onChanged: (value) =>
                            setState(() => _zoneFilter = value),
                      ),
                    ],
                  ],
                ),
              ),
              Expanded(
                child: visible.isEmpty
                    ? const Center(
                        child: Text(
                          'Nessuna visita in questo periodo.',
                          style: TextStyle(color: Colors.black54),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: visible.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final visit = visible[index];
                          final zone = extractZoneFromAddress(visit.address);
                          return Card(
                            color: AppCardTheme.surface,
                            child: ListTile(
                              title: Text(
                                visit.companyName.isEmpty
                                    ? 'Visita'
                                    : visit.companyName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(_formatDateTime(visit.scheduledAt)),
                                  Text(fieldVisitStatusLabel(visit.status)),
                                  if (zone != null) Text('Zona: $zone'),
                                  if (visit.address.isNotEmpty)
                                    Text(visit.address),
                                ],
                              ),
                              isThreeLine: true,
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _statChip(String label, String value) {
    return Chip(
      label: Text('$label: $value'),
      visualDensity: VisualDensity.compact,
    );
  }
}
