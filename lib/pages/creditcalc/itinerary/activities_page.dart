import 'package:flutter/material.dart';

import '../../../core/theme/app_card_theme.dart';
import '../../../widgets/field_visit_day_picker.dart';
import '../../../widgets/field_visit_link_picker.dart';
import '../../../widgets/voice_note_field.dart';
import '../../../models/field_activity.dart';
import '../../../services/field_activity_service.dart';
import '../../../services/gestione_menu_badge_service.dart';
import '../../../widgets/itinerary_notifications_card.dart';
import 'itinerary_page_shell.dart';

class ActivitiesPage extends StatefulWidget {
  const ActivitiesPage({super.key, this.personalArea = false});

  final bool personalArea;

  @override
  State<ActivitiesPage> createState() => _ActivitiesPageState();
}

class _ActivitiesPageState extends State<ActivitiesPage> {
  bool _busy = false;

  ItineraryPageShell get _shell =>
      ItineraryPageShell(personalArea: widget.personalArea);

  String _formatDate(DateTime value) {
    final d = value.day.toString().padLeft(2, '0');
    final m = value.month.toString().padLeft(2, '0');
    return '$d/$m/${value.year}';
  }

  DateTime _calendarDay(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  bool _isDueToday(DateTime dueAt) {
    final today = _calendarDay(DateTime.now());
    return _calendarDay(dueAt) == today;
  }

  bool _isOverdue(DateTime dueAt) =>
      _calendarDay(dueAt).isBefore(_calendarDay(DateTime.now()));

  Widget _metaChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _activityCard(FieldActivity item) {
    final accent = item.completed
        ? Colors.green
        : item.dueAt != null && _isOverdue(item.dueAt!)
            ? Colors.orange.shade800
            : const Color(0xFF1565C0);

    return Card(
      color: AppCardTheme.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppCardTheme.radius),
        side: BorderSide(color: accent.withValues(alpha: 0.22)),
      ),
      child: InkWell(
        onTap: () => _openEditor(activity: item),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 4, color: accent),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 14, 4, 14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Material(
                        color: accent.withValues(alpha: 0.12),
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: _busy
                              ? null
                              : () async {
                                  setState(() => _busy = true);
                                  try {
                                    await FieldActivityService.toggleCompleted(
                                      item,
                                    );
                                  } finally {
                                    if (mounted) {
                                      setState(() => _busy = false);
                                    }
                                  }
                                },
                          child: SizedBox(
                            width: 44,
                            height: 44,
                            child: Icon(
                              item.completed
                                  ? Icons.check_circle
                                  : Icons.radio_button_unchecked,
                              color: accent,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.title,
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                                height: 1.25,
                                decoration: item.completed
                                    ? TextDecoration.lineThrough
                                    : null,
                                color: item.completed
                                    ? Colors.black45
                                    : Colors.black87,
                              ),
                            ),
                            if (item.notes != null &&
                                item.notes!.trim().isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(
                                item.notes!.trim(),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.black54,
                                  height: 1.35,
                                ),
                              ),
                            ],
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              children: [
                                if (item.dueAt != null)
                                  _metaChip(
                                    icon: Icons.event_outlined,
                                    label: item.completed
                                        ? 'Scad. ${_formatDate(item.dueAt!)}'
                                        : _isDueToday(item.dueAt!)
                                            ? 'Scade oggi'
                                            : _isOverdue(item.dueAt!)
                                                ? 'Scaduta ${_formatDate(item.dueAt!)}'
                                                : 'Scadenza ${_formatDate(item.dueAt!)}',
                                    color: item.completed
                                        ? Colors.green
                                        : _isOverdue(item.dueAt!)
                                            ? Colors.orange.shade800
                                            : _isDueToday(item.dueAt!)
                                                ? const Color(0xFF1565C0)
                                                : Colors.blueGrey,
                                  ),
                                if (item.recurrenceDays != null)
                                  _metaChip(
                                    icon: Icons.repeat,
                                    label: 'Ogni ${item.recurrenceDays} gg',
                                    color: Colors.deepPurple,
                                  ),
                                if (item.visitId != null &&
                                    item.visitId!.isNotEmpty)
                                  _metaChip(
                                    icon: Icons.link,
                                    label: 'Collegata a visita',
                                    color: Colors.teal,
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      PopupMenuButton<String>(
                        onSelected: (action) async {
                          if (action == 'followup7') {
                            await FieldActivityService.scheduleFollowUp(
                              item,
                              days: 7,
                            );
                          } else if (action == 'followup30') {
                            await FieldActivityService.scheduleFollowUp(
                              item,
                              days: 30,
                            );
                          } else if (action == 'edit') {
                            await _openEditor(activity: item);
                          } else if (action == 'delete') {
                            await FieldActivityService.delete(item.id);
                          }
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(
                            value: 'followup7',
                            child: Text('Richiama tra 7 giorni'),
                          ),
                          PopupMenuItem(
                            value: 'followup30',
                            child: Text('Richiama tra 30 giorni'),
                          ),
                          PopupMenuItem(
                            value: 'edit',
                            child: Text('Modifica'),
                          ),
                          PopupMenuItem(
                            value: 'delete',
                            child: Text('Elimina'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openEditor({FieldActivity? activity}) async {
    final titleCtrl = TextEditingController(text: activity?.title ?? '');
    final notesCtrl = TextEditingController(text: activity?.notes ?? '');
    DateTime? dueAt = activity?.dueAt;
    String? visitId = activity?.visitId;
    int? recurrenceDays = activity?.recurrenceDays;

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text(activity == null ? 'Nuova attività' : 'Modifica attività'),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Titolo',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  VoiceNoteField(
                    controller: notesCtrl,
                    labelText: 'Note (opzionale)',
                  ),
                  const SizedBox(height: 12),
                  FieldVisitLinkPicker(
                    value: visitId,
                    onChanged: (v) => setLocal(() => visitId = v),
                  ),
                  const SizedBox(height: 12),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Ripetizione dopo completamento',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text('Nessuna'),
                        selected: recurrenceDays == null,
                        onSelected: (_) =>
                            setLocal(() => recurrenceDays = null),
                      ),
                      ChoiceChip(
                        label: const Text('Ogni 7 giorni'),
                        selected: recurrenceDays == 7,
                        onSelected: (_) => setLocal(() => recurrenceDays = 7),
                      ),
                      ChoiceChip(
                        label: const Text('Ogni 30 giorni'),
                        selected: recurrenceDays == 30,
                        onSelected: (_) => setLocal(() => recurrenceDays = 30),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Scadenza (opzionale)'),
                    subtitle: Text(
                      dueAt == null ? 'Nessuna scadenza' : _formatDate(dueAt!),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (dueAt != null)
                          IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () => setLocal(() => dueAt = null),
                          ),
                        IconButton(
                          icon: const Icon(Icons.event),
                          onPressed: () async {
                            final picked = await showFieldVisitDayPicker(
                              ctx,
                              initialDate: dueAt ?? DateTime.now(),
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2100),
                            );
                            if (picked != null) {
                              setLocal(() => dueAt = picked);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annulla'),
            ),
            FilledButton(
              onPressed: () {
                if (titleCtrl.text.trim().isEmpty) return;
                Navigator.pop(ctx, true);
              },
              child: const Text('Salva'),
            ),
          ],
        ),
      ),
    );

    if (saved != true || !mounted) {
      titleCtrl.dispose();
      notesCtrl.dispose();
      return;
    }

    setState(() => _busy = true);
    try {
      await FieldActivityService.save(
        id: activity?.id,
        title: titleCtrl.text,
        completed: activity?.completed ?? false,
        notes: notesCtrl.text,
        dueAt: dueAt,
        visitId: visitId,
        recurrenceDays: recurrenceDays,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Attività salvata.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Salvataggio non riuscito: $e')),
      );
    } finally {
      titleCtrl.dispose();
      notesCtrl.dispose();
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _shell.secondary(
      pageTitle: 'Attività',
      badgeKey: widget.personalArea ? GestioneMenuBadgeKey.activities : null,
      body: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.personalArea) ...[
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: ItineraryNotificationsConsentHint(),
                ),
              ],
              Padding(
                padding: ItineraryPageShell.headerPadding(context),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Compiti e follow-up collegati al lavoro sul territorio.',
                        style: TextStyle(color: Colors.black.withValues(alpha: 0.54)),
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: _busy ? null : () => _openEditor(),
                      icon: const Icon(Icons.add),
                      label: const Text('Nuova attività'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: StreamBuilder<List<FieldActivity>>(
                  stream: FieldActivityService.watchAll(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final items = snapshot.data ?? [];
                    if (items.isEmpty) {
                      return const Center(
                        child: Text(
                          'Nessuna attività. Aggiungine una per tenere traccia dei compiti.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.black54),
                        ),
                      );
                    }

                    return ListView.separated(
                      padding: ItineraryPageShell.listPadding(context),
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        return _activityCard(items[index]);
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
