import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_card_theme.dart';
import '../../../models/field_visit.dart';
import '../../../offline/repository/credit_calc_repository.dart';
import '../../../services/field_visit_service.dart';
import '../../../utils/field_visit_route_planner.dart';
import '../../../utils/itinerary_calendar_export.dart';
import '../../../widgets/address_field_with_scan.dart';
import '../../../widgets/field_visit_day_picker.dart';
import '../../../widgets/schedule_field_visit_dialog.dart';
import '../../../widgets/visit_practice_links.dart';
import '../../../widgets/voice_note_field.dart';
import '../commission_collections_shared.dart';
import 'itinerary_page_shell.dart';
import 'territory_map_page.dart';

class PracticeAgendaPage extends StatefulWidget {
  const PracticeAgendaPage({
    super.key,
    this.pageTitle = 'Agenda pratiche',
  });

  final String pageTitle;

  @override
  State<PracticeAgendaPage> createState() => _PracticeAgendaPageState();
}

class _PracticeAgendaPageState extends State<PracticeAgendaPage> {
  DateTime _selectedDay = DateTime.now();
  bool _busy = false;

  static const _shell = ItineraryPageShell();

  Future<void> _pickDay() async {
    final picked = await showFieldVisitDayPicker(
      context,
      initialDate: _selectedDay,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _selectedDay = picked);
    }
  }

  Future<void> _openVisitEditor({FieldVisit? visit}) async {
    final defaultScheduled = visit?.scheduledAt ??
        DateTime(
          _selectedDay.year,
          _selectedDay.month,
          _selectedDay.day,
          9,
          0,
        );

    final result = await showDialog<_VisitEditorResult>(
      context: context,
      builder: (ctx) => _VisitEditorDialog(
        visit: visit,
        defaultScheduled: defaultScheduled,
      ),
    );

    if (result == null || !mounted) return;

    setState(() => _busy = true);
    try {
      await FieldVisitService.save(
        id: visit?.id,
        companyName: result.companyName,
        address: result.address,
        scheduledAt: result.scheduledAt,
        status: result.status,
        notes: result.notes,
        creditorId: visit?.creditorId,
        creditorName: visit?.creditorName,
        calculationId: visit?.calculationId,
        routeOrder: visit?.routeOrder,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Visita salvata.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Salvataggio non riuscito: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _importFromCommissions() async {
    final docs = CommissionCollectionsHelper.commissionRecords(
      await CreditCalcRepository.instance.getCalculationRecords(),
    );
    if (!mounted) return;
    if (docs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nessun incasso da importare.')),
      );
      return;
    }

    final selected = await showDialog<CreditCalcRecord>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Importa da provvigioni'),
        content: SizedBox(
          width: 420,
          height: 320,
          child: ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final entry = docs[index];
              final data = entry.data;
              final company = CommissionCollectionsHelper.companyName(data);
              final date = CommissionCollectionsHelper.entryDate(data);
              return ListTile(
                title: Text(company.isEmpty ? 'Pratica' : company),
                subtitle: Text(
                  [
                    CommissionCollectionsHelper.creditorName(data),
                    if (date != null)
                      CommissionCollectionsHelper.formatDate(date),
                  ].where((s) => s.isNotEmpty).join(' · '),
                ),
                onTap: () => Navigator.pop(ctx, entry),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annulla'),
          ),
        ],
      ),
    );

    if (selected == null || !mounted) return;

    try {
      await showScheduleFieldVisitDialog(
        context,
        calculation: selected.data,
        calculationId: selected.id,
        initialDay: _selectedDay,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Importazione non riuscita: $e'),
        ),
      );
    }
  }

  Future<void> _setVisitStatus(FieldVisit visit, FieldVisitStatus status) async {
    setState(() => _busy = true);
    try {
      await FieldVisitService.updateStatus(visit.id, status);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Stato: ${fieldVisitStatusLabel(status)}')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _formatDateTime(DateTime value) {
    final d = value.day.toString().padLeft(2, '0');
    final m = value.month.toString().padLeft(2, '0');
    final h = value.hour.toString().padLeft(2, '0');
    final min = value.minute.toString().padLeft(2, '0');
    return '$d/$m/${value.year} $h:$min';
  }

  Future<void> _regeocodeVisit(FieldVisit visit) async {
    setState(() => _busy = true);
    try {
      final ok = await FieldVisitService.refreshGeocoding(visit);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ok
                ? 'Posizione aggiornata sulla mappa.'
                : 'Indirizzo non riconosciuto. Verifica via, civico e città.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _exportDayCalendar(List<FieldVisit> visits) async {
    if (visits.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nessuna visita da esportare.')),
      );
      return;
    }

    await ItineraryCalendarExport.downloadDayIcs(
      visits: visits,
      day: _selectedDay,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          kIsWeb
              ? 'File calendario scaricato.'
              : 'Calendario salvato e copiato negli appunti.',
        ),
      ),
    );
  }

  Future<void> _openGoogleCalendar(FieldVisit visit) async {
    final uri = ItineraryCalendarExport.googleCalendarUrlForVisit(visit);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _openDayRoute(List<FieldVisit> visits) async {
    final active = visits.where((v) => v.isActiveForItinerary).toList();
    await FieldVisitRoutePlanner.planAndOpen(context, active);
  }

  Color _statusColor(FieldVisitStatus status) {
    switch (status) {
      case FieldVisitStatus.planned:
        return Colors.blue;
      case FieldVisitStatus.completed:
        return Colors.green;
      case FieldVisitStatus.cancelled:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return _shell.secondary(
      pageTitle: widget.pageTitle,
      body: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: ItineraryPageShell.headerPadding(context),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _pickDay,
                      icon: const Icon(Icons.calendar_month),
                      label: Text(_formatDateTime(_selectedDay).split(' ').first),
                    ),
                    OutlinedButton.icon(
                      onPressed: _busy ? null : _importFromCommissions,
                      icon: const Icon(Icons.download),
                      label: const Text('Da provvigioni'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(context, rootNavigator: true).push(
                          MaterialPageRoute(
                            builder: (_) => TerritoryMapPage(
                              day: _selectedDay,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.map_outlined),
                      label: const Text('Mappa giorno'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _busy
                          ? null
                          : () {
                              FieldVisitService.watchForDay(_selectedDay)
                                  .first
                                  .then(_openDayRoute);
                            },
                      icon: const Icon(Icons.directions),
                      label: const Text('Percorso giornata'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _busy
                          ? null
                          : () {
                              FieldVisitService.watchForDay(_selectedDay)
                                  .first
                                  .then(_exportDayCalendar);
                            },
                      icon: const Icon(Icons.calendar_month_outlined),
                      label: const Text('Esporta ICS'),
                    ),
                    FilledButton.icon(
                      onPressed: _busy ? null : () => _openVisitEditor(),
                      icon: const Icon(Icons.add),
                      label: const Text('Nuova visita'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: StreamBuilder<List<FieldVisit>>(
                  stream: FieldVisitService.watchForDay(_selectedDay),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final visits = snapshot.data ?? [];
                    if (visits.isEmpty) {
                      return const Center(
                        child: Text(
                          'Nessuna visita in agenda per questo giorno.',
                          style: TextStyle(color: Colors.black54),
                        ),
                      );
                    }

                    return ReorderableListView.builder(
                      padding: ItineraryPageShell.listPadding(context),
                      itemCount: visits.length,
                      onReorder: (oldIndex, newIndex) async {
                        if (newIndex > oldIndex) newIndex--;
                        final reordered = List<FieldVisit>.from(visits);
                        final moved = reordered.removeAt(oldIndex);
                        reordered.insert(newIndex, moved);
                        setState(() => _busy = true);
                        try {
                          await FieldVisitService.saveRouteOrder(reordered);
                        } finally {
                          if (mounted) setState(() => _busy = false);
                        }
                      },
                      itemBuilder: (context, index) {
                        final visit = visits[index];
                        return Card(
                          key: ValueKey(visit.id),
                          color: AppCardTheme.surface,
                          margin: const EdgeInsets.only(bottom: 10),
                          child: ListTile(
                            leading: ReorderableDragStartListener(
                              index: index,
                              child: CircleAvatar(
                                backgroundColor: _statusColor(visit.status)
                                    .withValues(alpha: 0.15),
                                child: Icon(
                                  Icons.drag_handle,
                                  color: _statusColor(visit.status),
                                ),
                              ),
                            ),
                            title: Text(
                              visit.companyName.isEmpty
                                  ? 'Visita'
                                  : visit.companyName,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (visit.address.isNotEmpty)
                                  Text(visit.address),
                                if (visit.needsGeocoding)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.orange.shade50,
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(
                                          color: Colors.orange.shade200,
                                        ),
                                      ),
                                      child: Text(
                                        'Mappa non disponibile',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.orange.shade900,
                                        ),
                                      ),
                                    ),
                                  ),
                                Text(
                                  '${_formatDateTime(visit.scheduledAt)} · '
                                  '${fieldVisitStatusLabel(visit.status)}',
                                ),
                                if (visit.creditorName != null &&
                                    visit.creditorName!.isNotEmpty)
                                  Text('Creditore: ${visit.creditorName}'),
                                VisitPracticeLinks(visit: visit),
                              ],
                            ),
                            isThreeLine: true,
                            onTap: () => _openVisitEditor(visit: visit),
                            onLongPress: () => _setVisitStatus(
                              visit,
                              visit.status == FieldVisitStatus.completed
                                  ? FieldVisitStatus.planned
                                  : FieldVisitStatus.completed,
                            ),
                            trailing: PopupMenuButton<String>(
                              onSelected: (action) async {
                                if (action == 'regeocode') {
                                  await _regeocodeVisit(visit);
                                } else if (action == 'planned') {
                                  await _setVisitStatus(
                                    visit,
                                    FieldVisitStatus.planned,
                                  );
                                } else if (action == 'completed') {
                                  await _setVisitStatus(
                                    visit,
                                    FieldVisitStatus.completed,
                                  );
                                } else if (action == 'cancelled') {
                                  await _setVisitStatus(
                                    visit,
                                    FieldVisitStatus.cancelled,
                                  );
                                } else if (action == 'calendar') {
                                  await _openGoogleCalendar(visit);
                                } else if (action == 'edit') {
                                  await _openVisitEditor(visit: visit);
                                } else if (action == 'delete') {
                                  await FieldVisitService.delete(visit.id);
                                }
                              },
                              itemBuilder: (_) => [
                                if (visit.needsGeocoding)
                                  const PopupMenuItem(
                                    value: 'regeocode',
                                    child: Text('Aggiorna geolocalizzazione'),
                                  ),
                                const PopupMenuItem(
                                  value: 'planned',
                                  child: Text('Segna in programma'),
                                ),
                                const PopupMenuItem(
                                  value: 'completed',
                                  child: Text('Segna completata'),
                                ),
                                const PopupMenuItem(
                                  value: 'cancelled',
                                  child: Text('Segna annullata'),
                                ),
                                const PopupMenuItem(
                                  value: 'calendar',
                                  child: Text('Aggiungi a Google Calendar'),
                                ),
                                const PopupMenuItem(
                                  value: 'edit',
                                  child: Text('Modifica'),
                                ),
                                const PopupMenuItem(
                                  value: 'delete',
                                  child: Text('Elimina'),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
          if (_busy)
            const Positioned.fill(
              child: ColoredBox(
                color: Color(0x33FFFFFF),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
        ],
      ),
    );
  }
}

class _VisitEditorResult {
  const _VisitEditorResult({
    required this.companyName,
    required this.address,
    required this.notes,
    required this.scheduledAt,
    required this.status,
  });

  final String companyName;
  final String address;
  final String notes;
  final DateTime scheduledAt;
  final FieldVisitStatus status;
}

class _VisitEditorDialog extends StatefulWidget {
  const _VisitEditorDialog({
    required this.visit,
    required this.defaultScheduled,
  });

  final FieldVisit? visit;
  final DateTime defaultScheduled;

  @override
  State<_VisitEditorDialog> createState() => _VisitEditorDialogState();
}

class _VisitEditorDialogState extends State<_VisitEditorDialog> {
  late final TextEditingController _companyCtrl;
  late final TextEditingController _addressCtrl;
  late final TextEditingController _notesCtrl;
  late DateTime _scheduled;
  late FieldVisitStatus _status;

  @override
  void initState() {
    super.initState();
    final visit = widget.visit;
    _companyCtrl = TextEditingController(text: visit?.companyName ?? '');
    _addressCtrl = TextEditingController(text: visit?.address ?? '');
    _notesCtrl = TextEditingController(text: visit?.notes ?? '');
    _scheduled = visit?.scheduledAt ?? widget.defaultScheduled;
    _status = visit?.status ?? FieldVisitStatus.planned;
  }

  @override
  void dispose() {
    _companyCtrl.dispose();
    _addressCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  String _formatDateTime(DateTime value) {
    final d = value.day.toString().padLeft(2, '0');
    final m = value.month.toString().padLeft(2, '0');
    final h = value.hour.toString().padLeft(2, '0');
    final min = value.minute.toString().padLeft(2, '0');
    return '$d/$m/${value.year} $h:$min';
  }

  void _save() {
    if (_companyCtrl.text.trim().isEmpty) return;
    Navigator.pop(
      context,
      _VisitEditorResult(
        companyName: _companyCtrl.text,
        address: _addressCtrl.text,
        notes: _notesCtrl.text,
        scheduledAt: _scheduled,
        status: _status,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final visit = widget.visit;

    return AlertDialog(
      title: Text(visit == null ? 'Nuova visita' : 'Modifica visita'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _companyCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Ragione sociale / debitore',
                  hintText: 'Es. Verdone Alfio',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              AddressFieldWithScan(
                controller: _addressCtrl,
                companyNameController: _companyCtrl,
                labelText: 'Indirizzo visita',
                hintText: 'Es. Via Roma, 143 - 80100 Napoli',
                onScanned: () => setState(() {}),
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Data e ora'),
                subtitle: Text(_formatDateTime(_scheduled)),
                trailing: IconButton(
                  icon: const Icon(Icons.schedule),
                  onPressed: () async {
                    final picked = await pickFieldVisitDateAndTime(
                      context,
                      initial: _scheduled,
                      excludeVisitId: visit?.id,
                    );
                    if (picked == null || !mounted) return;
                    setState(() => _scheduled = picked);
                  },
                ),
              ),
              DropdownButtonFormField<FieldVisitStatus>(
                value: _status,
                decoration: const InputDecoration(
                  labelText: 'Stato',
                  border: OutlineInputBorder(),
                ),
                items: FieldVisitStatus.values
                    .map(
                      (s) => DropdownMenuItem(
                        value: s,
                        child: Text(fieldVisitStatusLabel(s)),
                      ),
                    )
                    .toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _status = v);
                },
              ),
              const SizedBox(height: 12),
              VoiceNoteField(controller: _notesCtrl),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annulla'),
        ),
        FilledButton(
          onPressed: _save,
          child: const Text('Salva'),
        ),
      ],
    );
  }
}
