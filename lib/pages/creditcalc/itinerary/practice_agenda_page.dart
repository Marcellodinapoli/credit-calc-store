import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_card_theme.dart';
import '../../../models/field_visit.dart';
import '../../../offline/repository/credit_calc_repository.dart';
import '../../../services/field_visit_service.dart';
import '../../../services/installment_monitor_service.dart';
import '../../../services/itinerary_nav_badge_notifier.dart';
import '../../../utils/field_visit_route_planner.dart';
import '../../../utils/itinerary_calendar_export.dart';
import '../../../widgets/address_field_with_scan.dart';
import '../../../widgets/field_visit_day_picker.dart';
import '../../../widgets/schedule_field_visit_dialog.dart';
import '../../../widgets/pdr_card_details.dart';
import '../../../widgets/visit_practice_links.dart';
import '../../../widgets/voice_note_field.dart';
import '../commission_collections_shared.dart';
import '../debtor_contact_page.dart';
import 'itinerary_page_shell.dart';
import 'territory_map_page.dart';

class PracticeAgendaPage extends StatefulWidget {
  const PracticeAgendaPage({
    super.key,
    this.pageTitle = 'Agenda pratiche',
    this.focusVisitId,
  });

  final String pageTitle;
  final String? focusVisitId;

  @override
  State<PracticeAgendaPage> createState() => _PracticeAgendaPageState();
}

class _PracticeAgendaPageState extends State<PracticeAgendaPage> {
  DateTime _selectedDay = DateTime.now();
  bool _busy = false;
  bool _focusApplied = false;

  static const _shell = ItineraryPageShell();

  @override
  void initState() {
    super.initState();
    ItineraryNavBadgeNotifier.instance.clearAppointments();
    WidgetsBinding.instance.addPostFrameCallback((_) => _applyFocusVisit());
  }

  Future<void> _applyFocusVisit() async {
    final id = widget.focusVisitId?.trim() ?? '';
    if (_focusApplied || id.isEmpty) return;
    _focusApplied = true;
    try {
      final visits = await FieldVisitService.fetchAllForUser();
      FieldVisit? match;
      for (final v in visits) {
        if (v.id == id) {
          match = v;
          break;
        }
      }
      if (match == null || !mounted) return;
      final day = match.scheduledAt;
      setState(() {
        _selectedDay = DateTime(day.year, day.month, day.day);
      });
    } catch (_) {}
  }

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

    final editor = await showDialog<_VisitEditorResult>(
      context: context,
      builder: (ctx) => _VisitEditorDialog(
        visit: visit,
        defaultScheduled: defaultScheduled,
      ),
    );

    if (editor == null || !mounted) return;

    final rescheduled = visit != null &&
        !_sameMinute(editor.scheduledAt, visit.scheduledAt);
    final status =
        rescheduled ? FieldVisitStatus.planned : editor.status;

    setState(() => _busy = true);
    try {
      final saved = await FieldVisitService.save(
        id: visit?.id,
        companyName: editor.companyName,
        address: editor.address,
        scheduledAt: editor.scheduledAt,
        status: status,
        notes: editor.notes,
        creditorId: visit?.creditorId,
        creditorName: visit?.creditorName,
        calculationId: visit?.calculationId,
        routeOrder: visit?.routeOrder,
      );
      if (!mounted) return;

      final schedule = saved.schedule;
      if (rescheduled) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              schedule.scheduled && schedule.notifyAt != null
                  ? 'Visita riprogrammata e rimessa in programma. '
                      'Avviso alle '
                      '${schedule.notifyAt!.hour.toString().padLeft(2, '0')}:'
                      '${schedule.notifyAt!.minute.toString().padLeft(2, '0')}.'
                  : 'Visita riprogrammata e rimessa in programma.',
            ),
          ),
        );
      } else if (status != FieldVisitStatus.planned) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Visita salvata (${fieldVisitStatusLabel(status)}). '
              'Notifica disattivata.',
            ),
          ),
        );
      } else if (schedule.scheduled && schedule.notifyAt != null) {
        final at = schedule.notifyAt!;
        final h = at.hour.toString().padLeft(2, '0');
        final m = at.minute.toString().padLeft(2, '0');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Visita salvata. Avviso programmato alle $h:$m '
              '(e all\'orario dell\'appuntamento).',
            ),
          ),
        );
      } else if (schedule.issue != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Visita salvata, ma l\'avviso non è programmato: '
              '${schedule.issue}',
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Visita salvata.')),
        );
      }
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
      final notifyOff = status != FieldVisitStatus.planned;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            notifyOff
                ? 'Stato: ${fieldVisitStatusLabel(status)}. Notifica disattivata.'
                : 'Stato: ${fieldVisitStatusLabel(status)}. Notifica riattivata.',
          ),
        ),
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

  Future<void> _openDebtorContact() async {
    await Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(builder: (_) => const DebtorContactPage()),
    );
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
        return const Color(0xFF1565C0);
      case FieldVisitStatus.completed:
        return const Color(0xFF2E7D32);
      case FieldVisitStatus.cancelled:
        return const Color(0xFF757575);
    }
  }

  Color _cardColor(FieldVisitStatus status) {
    switch (status) {
      case FieldVisitStatus.planned:
        return AppCardTheme.surface;
      case FieldVisitStatus.completed:
        return const Color(0xFFE8F5E9);
      case FieldVisitStatus.cancelled:
        return const Color(0xFFEEEEEE);
    }
  }

  IconData _statusIcon(FieldVisitStatus status) {
    switch (status) {
      case FieldVisitStatus.planned:
        return Icons.event_available;
      case FieldVisitStatus.completed:
        return Icons.check_circle;
      case FieldVisitStatus.cancelled:
        return Icons.cancel;
    }
  }

  static bool _sameMinute(DateTime a, DateTime b) =>
      a.year == b.year &&
      a.month == b.month &&
      a.day == b.day &&
      a.hour == b.hour &&
      a.minute == b.minute;

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
                        final accent = _statusColor(visit.status);
                        return Card(
                          key: ValueKey(visit.id),
                          color: _cardColor(visit.status),
                          margin: const EdgeInsets.only(bottom: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              AppCardTheme.radius,
                            ),
                            side: BorderSide(
                              color: accent.withValues(alpha: 0.35),
                            ),
                          ),
                          child: ListTile(
                            leading: ReorderableDragStartListener(
                              index: index,
                              child: CircleAvatar(
                                backgroundColor:
                                    accent.withValues(alpha: 0.18),
                                child: Icon(
                                  _statusIcon(visit.status),
                                  color: accent,
                                ),
                              ),
                            ),
                            title: Text(
                              visit.companyName.isEmpty
                                  ? 'Visita'
                                  : visit.companyName,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: visit.status ==
                                        FieldVisitStatus.cancelled
                                    ? Colors.black54
                                    : null,
                                decoration: visit.status ==
                                        FieldVisitStatus.cancelled
                                    ? TextDecoration.lineThrough
                                    : null,
                              ),
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
                                PdrCardDetailsLines(
                                  detailsFuture:
                                      InstallmentMonitorService
                                          .resolvePdrDetailsForVisit(visit),
                                ),
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
                                } else if (action == 'message') {
                                  await _openDebtorContact();
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
                                  value: 'message',
                                  child: Text('Invia messaggio'),
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
                    setState(() {
                      _scheduled = picked;
                      final original = visit?.scheduledAt;
                      if (original != null &&
                          !_PracticeAgendaPageState._sameMinute(
                            picked,
                            original,
                          )) {
                        _status = FieldVisitStatus.planned;
                      }
                    });
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
