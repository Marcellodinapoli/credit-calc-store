import 'package:flutter/material.dart';

import '../../../core/theme/app_card_theme.dart';
import '../../../widgets/field_visit_link_picker.dart';
import '../../../widgets/voice_note_field.dart';
import '../../../models/field_activity.dart';
import '../../../services/field_activity_service.dart';
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
                            final picked = await showDatePicker(
                              context: ctx,
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
      body: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
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
                        final item = items[index];
                        return Card(
                          color: AppCardTheme.surface,
                          child: ListTile(
                            leading: Checkbox(
                              value: item.completed,
                              onChanged: _busy
                                  ? null
                                  : (_) async {
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
                            ),
                            title: Text(
                              item.title,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                decoration: item.completed
                                    ? TextDecoration.lineThrough
                                    : null,
                                color: item.completed ? Colors.black45 : null,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (item.notes != null && item.notes!.isNotEmpty)
                                  Text(item.notes!),
                                if (item.dueAt != null)
                                  Text('Scadenza: ${_formatDate(item.dueAt!)}'),
                                if (item.recurrenceDays != null)
                                  Text(
                                    'Ripete ogni ${item.recurrenceDays} giorni',
                                    style: const TextStyle(color: Colors.black54),
                                  ),
                              ],
                            ),
                            isThreeLine: true,
                            onTap: () => _openEditor(activity: item),
                            trailing: PopupMenuButton<String>(
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
