import 'package:flutter/material.dart';

import '../../../core/theme/app_card_theme.dart';
import '../../../widgets/field_visit_link_picker.dart';
import '../../../models/field_reminder.dart';
import '../../../services/field_reminder_service.dart';
import 'itinerary_page_shell.dart';

class RemindersPage extends StatefulWidget {
  const RemindersPage({super.key, this.personalArea = false});

  final bool personalArea;

  @override
  State<RemindersPage> createState() => _RemindersPageState();
}

class _RemindersPageState extends State<RemindersPage> {
  bool _busy = false;

  ItineraryPageShell get _shell =>
      ItineraryPageShell(personalArea: widget.personalArea);

  String _formatDateTime(DateTime value) {
    final d = value.day.toString().padLeft(2, '0');
    final m = value.month.toString().padLeft(2, '0');
    final h = value.hour.toString().padLeft(2, '0');
    final min = value.minute.toString().padLeft(2, '0');
    return '$d/$m/${value.year} $h:$min';
  }

  Future<void> _openEditor({FieldReminder? reminder}) async {
    final titleCtrl = TextEditingController(text: reminder?.title ?? '');
    final notesCtrl = TextEditingController(text: reminder?.notes ?? '');
    var remindAt = reminder?.remindAt ??
        DateTime.now().add(const Duration(hours: 1));
    String? visitId = reminder?.visitId;

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text(reminder == null ? 'Nuovo promemoria' : 'Modifica promemoria'),
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
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Data e ora'),
                    subtitle: Text(_formatDateTime(remindAt)),
                    trailing: IconButton(
                      icon: const Icon(Icons.schedule),
                      onPressed: () async {
                        final date = await showDatePicker(
                          context: ctx,
                          initialDate: remindAt,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2100),
                        );
                        if (date == null) return;
                        if (!ctx.mounted) return;
                        final time = await showTimePicker(
                          context: ctx,
                          initialTime: TimeOfDay.fromDateTime(remindAt),
                        );
                        if (time == null) return;
                        setLocal(() {
                          remindAt = DateTime(
                            date.year,
                            date.month,
                            date.day,
                            time.hour,
                            time.minute,
                          );
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  FieldVisitLinkPicker(
                    value: visitId,
                    onChanged: (v) => setLocal(() => visitId = v),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: notesCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Note (opzionale)',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
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
      await FieldReminderService.save(
        id: reminder?.id,
        title: titleCtrl.text,
        remindAt: remindAt,
        notes: notesCtrl.text,
        visitId: visitId,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Promemoria salvato.')),
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
      pageTitle: 'Promemoria',
      body: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: ItineraryPageShell.headerPadding(context),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Avvisi programmati per richiami, scadenze e follow-up. '
                      'Con le notifiche itinerario attive ricevi anche un push '
                      'all\'orario impostato.',
                      style: TextStyle(color: Colors.black.withValues(alpha: 0.54)),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        FilledButton.icon(
                          onPressed: _busy ? null : () => _openEditor(),
                          icon: const Icon(Icons.add_alarm),
                          label: const Text('Nuovo promemoria'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: StreamBuilder<List<FieldReminder>>(
                  stream: FieldReminderService.watchUpcoming(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final items = snapshot.data ?? [];
                    if (items.isEmpty) {
                      return const Center(
                        child: Text(
                          'Nessun promemoria. Programmane uno per non dimenticare le scadenze.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.black54),
                        ),
                      );
                    }

                    final now = DateTime.now();
                    return ListView.separated(
                      padding: ItineraryPageShell.listPadding(context),
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final item = items[index];
                        final isPast = item.remindAt.isBefore(now);
                        return Card(
                          color: AppCardTheme.surface,
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: (isPast ? Colors.orange : Colors.blue)
                                  .withValues(alpha: 0.15),
                              child: Icon(
                                isPast ? Icons.notifications_active : Icons.alarm,
                                color: isPast ? Colors.orange : Colors.blue,
                              ),
                            ),
                            title: Text(
                              item.title,
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(_formatDateTime(item.remindAt)),
                                if (item.notes != null && item.notes!.isNotEmpty)
                                  Text(item.notes!),
                                if (item.pushSent)
                                  const Text(
                                    'Notifica inviata',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.green,
                                    ),
                                  ),
                              ],
                            ),
                            isThreeLine: true,
                            onTap: () => _openEditor(reminder: item),
                            trailing: PopupMenuButton<String>(
                              onSelected: (action) async {
                                if (action == 'edit') {
                                  await _openEditor(reminder: item);
                                } else if (action == 'delete') {
                                  await FieldReminderService.delete(item.id);
                                }
                              },
                              itemBuilder: (_) => const [
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
