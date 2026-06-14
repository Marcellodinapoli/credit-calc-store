import 'package:flutter/material.dart';

import '../services/creditor_visit_address_service.dart';
import '../services/field_visit_service.dart';
import 'address_field_with_scan.dart';
import 'field_visit_day_picker.dart';

class ScheduleFieldVisitResult {
  const ScheduleFieldVisitResult({
    required this.address,
    required this.scheduledAt,
  });

  final String address;
  final DateTime scheduledAt;
}

/// Programma una visita da dati incasso/pratica (provvigioni).
Future<bool> showScheduleFieldVisitDialog(
  BuildContext context, {
  required Map<String, dynamic> calculation,
  required String calculationId,
  DateTime? initialDay,
}) async {
  final result = await showDialog<ScheduleFieldVisitResult>(
    context: context,
    builder: (ctx) => _ScheduleFieldVisitDialog(
      calculation: calculation,
      initialDay: initialDay ?? DateTime.now(),
    ),
  );

  if (result == null || !context.mounted) return false;

  try {
    await FieldVisitService.importFromCalculation(
      calculation: calculation,
      calculationId: calculationId,
      scheduledAt: result.scheduledAt,
      address: result.address,
    );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Visita aggiunta in agenda.')),
      );
    }
    return true;
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Impossibile programmare la visita: $e')),
      );
    }
    return false;
  }
}

class _ScheduleFieldVisitDialog extends StatefulWidget {
  const _ScheduleFieldVisitDialog({
    required this.calculation,
    required this.initialDay,
  });

  final Map<String, dynamic> calculation;
  final DateTime initialDay;

  @override
  State<_ScheduleFieldVisitDialog> createState() =>
      _ScheduleFieldVisitDialogState();
}

class _ScheduleFieldVisitDialogState extends State<_ScheduleFieldVisitDialog> {
  late final TextEditingController _addressCtrl;
  late DateTime _scheduled;

  @override
  void initState() {
    super.initState();
    _addressCtrl = TextEditingController();
    final day = widget.initialDay;
    _scheduled = DateTime(day.year, day.month, day.day, 10, 0);
    _loadSuggestedAddress();
  }

  Future<void> _loadSuggestedAddress() async {
    final creditorId = widget.calculation['creditorId']?.toString();
    try {
      final suggested = await CreditorVisitAddressService.lookupAddress(
        creditorId: creditorId,
      );
      if (!mounted || suggested == null || suggested.isEmpty) return;
      _addressCtrl.text = suggested;
    } catch (_) {
      // Prosegue senza indirizzo suggerito.
    }
  }

  @override
  void dispose() {
    _addressCtrl.dispose();
    super.dispose();
  }

  void _confirm() {
    Navigator.pop(
      context,
      ScheduleFieldVisitResult(
        address: _addressCtrl.text,
        scheduledAt: _scheduled,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final calculation = widget.calculation;
    final creditorName = (calculation['creditorName'] ?? '').toString();

    return AlertDialog(
      title: const Text('Programma visita'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                (calculation['companyName'] ?? 'Pratica').toString(),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              if (creditorName.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'Creditore: $creditorName',
                    style: const TextStyle(color: Colors.black54),
                  ),
                ),
              const SizedBox(height: 12),
              AddressFieldWithScan(
                controller: _addressCtrl,
                labelText: 'Indirizzo visita',
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
                    );
                    if (picked == null || !mounted) return;
                    setState(() => _scheduled = picked);
                  },
                ),
              ),
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
          onPressed: _confirm,
          child: const Text('Aggiungi in agenda'),
        ),
      ],
    );
  }
}

String _formatDateTime(DateTime value) {
  final d = value.day.toString().padLeft(2, '0');
  final m = value.month.toString().padLeft(2, '0');
  final h = value.hour.toString().padLeft(2, '0');
  final min = value.minute.toString().padLeft(2, '0');
  return '$d/$m/${value.year} $h:$min';
}
