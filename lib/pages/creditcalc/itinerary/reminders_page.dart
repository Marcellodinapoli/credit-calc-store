import 'package:flutter/material.dart';

import '../../../core/theme/app_card_theme.dart';
import '../../../widgets/field_visit_day_picker.dart';
import '../../../widgets/field_visit_link_picker.dart';
import '../../../models/field_reminder.dart';
import '../../../services/field_reminder_service.dart';
import '../../../services/installment_monitor_service.dart';
import '../../../widgets/pdr_card_details.dart';
import 'itinerary_page_shell.dart';

enum _ReminderMonthFilter {
  currentMonth('Mese in corso'),
  upcomingMonths('Prossimi mesi'),
  all('Tutti');

  const _ReminderMonthFilter(this.label);
  final String label;
}

class RemindersPage extends StatefulWidget {
  const RemindersPage({super.key});

  @override
  State<RemindersPage> createState() => _RemindersPageState();
}

class _RemindersPageState extends State<RemindersPage> {
  bool _busy = false;
  _ReminderMonthFilter _monthFilter = _ReminderMonthFilter.currentMonth;

  static const _shell = ItineraryPageShell();

  bool _isCurrentMonth(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month;
  }

  bool _isFutureMonth(DateTime date) {
    final now = DateTime.now();
    return date.year > now.year ||
        (date.year == now.year && date.month > now.month);
  }

  ({List<FieldReminder> current, List<FieldReminder> upcoming})
      _partitionByMonth(List<FieldReminder> items) {
    final current = <FieldReminder>[];
    final upcoming = <FieldReminder>[];
    for (final item in items) {
      if (_isCurrentMonth(item.remindAt)) {
        current.add(item);
      } else if (_isFutureMonth(item.remindAt)) {
        upcoming.add(item);
      }
    }
    return (current: current, upcoming: upcoming);
  }

  List<String> _availableReminderTitles(List<FieldReminder> items) {
    final unique = <String>{};
    for (final item in items) {
      final title = item.title.trim();
      if (title.isNotEmpty) unique.add(title);
    }
    final titles = unique.toList()..sort();
    return titles;
  }

  Future<void> _pickReminderTitle(List<String> titles) async {
    final picked = await showModalBottomSheet<String?>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text(
                'Programma promemoria per',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            for (final title in titles)
              ListTile(
                leading: const Icon(Icons.person_outline),
                title: Text(title),
                onTap: () => Navigator.pop(context, title),
              ),
          ],
        ),
      ),
    );
    if (!mounted || picked == null || picked.isEmpty) return;
    await _openEditor(initialTitle: picked);
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: Colors.grey.shade700,
          letterSpacing: 0.2,
        ),
      ),
    );
  }

  Widget _reminderCard(FieldReminder item, DateTime now) {
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
            PdrCardDetailsLines(
              detailsFuture:
                  InstallmentMonitorService.resolvePdrDetailsForReminder(item),
            ),
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
  }

  Widget _buildFilteredList(List<FieldReminder> items) {
    final now = DateTime.now();
    final parts = _partitionByMonth(items);

    List<FieldReminder> visible;
    switch (_monthFilter) {
      case _ReminderMonthFilter.currentMonth:
        visible = parts.current;
      case _ReminderMonthFilter.upcomingMonths:
        visible = parts.upcoming;
      case _ReminderMonthFilter.all:
        visible = [...parts.current, ...parts.upcoming];
    }

    if (visible.isEmpty) {
      final message = switch (_monthFilter) {
        _ReminderMonthFilter.currentMonth =>
          'Nessun promemoria per il mese in corso.',
        _ReminderMonthFilter.upcomingMonths =>
          'Nessun promemoria nei prossimi mesi.',
        _ReminderMonthFilter.all =>
          'Nessun promemoria. Programmane uno per non dimenticare le scadenze.',
      };
      return Center(
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.black54),
        ),
      );
    }

    if (_monthFilter != _ReminderMonthFilter.all) {
      return ListView.separated(
        padding: ItineraryPageShell.listPadding(context),
        itemCount: visible.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) =>
            _reminderCard(visible[index], now),
      );
    }

    return ListView(
      padding: ItineraryPageShell.listPadding(context),
      children: [
        if (parts.current.isNotEmpty) ...[
          _sectionHeader('Mese in corso'),
          for (var i = 0; i < parts.current.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            _reminderCard(parts.current[i], now),
          ],
        ],
        if (parts.upcoming.isNotEmpty) ...[
          if (parts.current.isNotEmpty) const SizedBox(height: 20),
          _sectionHeader('Prossimi mesi'),
          for (var i = 0; i < parts.upcoming.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            _reminderCard(parts.upcoming[i], now),
          ],
        ],
      ],
    );
  }

  String _formatDateTime(DateTime value) {
    final d = value.day.toString().padLeft(2, '0');
    final m = value.month.toString().padLeft(2, '0');
    final h = value.hour.toString().padLeft(2, '0');
    final min = value.minute.toString().padLeft(2, '0');
    return '$d/$m/${value.year} $h:$min';
  }

  String _rateizzoTechnicalNotes(String notes) {
    final technical = notes
        .split('\n')
        .map((line) => line.trim())
        .where((line) {
          if (line.isEmpty) return false;
          if (line.startsWith('rateizzo-monitor:')) return true;
          return RegExp(r'^Rata \d+/\d+ · Scadenza PDR:').hasMatch(line);
        })
        .join('\n');
    return technical;
  }

  String _rateizzoUserNotes(String? notes) {
    if (notes == null || notes.trim().isEmpty) return '';
    return notes
        .split('\n')
        .map((line) => line.trim())
        .where((line) {
          if (line.isEmpty) return false;
          if (line.startsWith('rateizzo-monitor:')) return false;
          return !RegExp(r'^Rata \d+/\d+ · Scadenza PDR:').hasMatch(line);
        })
        .join('\n');
  }

  String? _notesForEditor(FieldReminder? reminder) {
    if (reminder == null) return null;
    if (!InstallmentMonitorService.isRateizzoReminder(reminder)) {
      return reminder.notes;
    }
    final userNotes = _rateizzoUserNotes(reminder.notes);
    return userNotes.isEmpty ? null : userNotes;
  }

  String? _notesForSave(FieldReminder? reminder, String editorText) {
    final userNotes = editorText.trim();
    if (reminder == null ||
        !InstallmentMonitorService.isRateizzoReminder(reminder)) {
      return userNotes.isEmpty ? null : userNotes;
    }

    final technical = _rateizzoTechnicalNotes(reminder.notes ?? '');
    if (userNotes.isEmpty) {
      return technical.isEmpty ? null : technical;
    }
    if (technical.isEmpty) return userNotes;
    return '$technical\n$userNotes';
  }

  Future<void> _openEditor({
    FieldReminder? reminder,
    String? initialTitle,
  }) async {
    final titleCtrl = TextEditingController(
      text: reminder?.title ?? initialTitle ?? '',
    );
    final notesCtrl = TextEditingController(text: _notesForEditor(reminder) ?? '');
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
                        final picked = await pickFieldVisitDateAndTime(
                          ctx,
                          initial: remindAt,
                          checkAgendaConflict: false,
                        );
                        if (picked == null) return;
                        setLocal(() => remindAt = picked);
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
      final result = await FieldReminderService.save(
        id: reminder?.id,
        title: titleCtrl.text,
        remindAt: remindAt,
        notes: _notesForSave(reminder, notesCtrl.text),
        visitId: visitId,
      );
      if (!mounted) return;

      final schedule = result.schedule;
      if (schedule.scheduled && schedule.notifyAt != null) {
        final at = schedule.notifyAt!;
        final h = at.hour.toString().padLeft(2, '0');
        final m = at.minute.toString().padLeft(2, '0');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Promemoria salvato. Avviso programmato alle $h:$m.',
            ),
          ),
        );
      } else if (schedule.issue != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Promemoria salvato, ma l\'avviso non è programmato: '
              '${schedule.issue}',
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Promemoria salvato.')),
        );
      }
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
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final filter in _ReminderMonthFilter.values)
                          FilterChip(
                            label: Text(filter.label),
                            selected: _monthFilter == filter,
                            onSelected: (selected) {
                              if (!selected) return;
                              setState(() => _monthFilter = filter);
                            },
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    StreamBuilder<List<FieldReminder>>(
                      stream: FieldReminderService.watchUpcoming(),
                      builder: (context, snapshot) {
                        final items = snapshot.data ?? [];
                        return OutlinedButton.icon(
                          onPressed: items.isEmpty
                              ? null
                              : () => _pickReminderTitle(
                                    _availableReminderTitles(items),
                                  ),
                          icon: const Icon(Icons.person_search),
                          label: const Text('Seleziona nominativo'),
                        );
                      },
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

                    return _buildFilteredList(items);
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
