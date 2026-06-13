import 'package:flutter/material.dart';

import '../services/creditor_visit_address_service.dart';
import '../services/field_visit_service.dart';
import 'address_field_with_scan.dart';
import 'field_visit_day_picker.dart';

/// Programma una visita da dati incasso/pratica (provvigioni).
Future<bool> showScheduleFieldVisitDialog(
  BuildContext context, {
  required Map<String, dynamic> calculation,
  required String calculationId,
  DateTime? initialDay,
}) async {
  final day = initialDay ?? DateTime.now();
  final addressCtrl = TextEditingController();
  final creditorId = calculation['creditorId']?.toString();

  final suggested =
      await CreditorVisitAddressService.lookupAddress(creditorId: creditorId);
  if (suggested != null && suggested.isNotEmpty) {
    addressCtrl.text = suggested;
  }

  var scheduled = DateTime(day.year, day.month, day.day, 10, 0);

  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setLocal) => AlertDialog(
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
                if ((calculation['creditorName'] ?? '').toString().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Creditore: ${calculation['creditorName']}',
                      style: const TextStyle(color: Colors.black54),
                    ),
                  ),
                const SizedBox(height: 12),
                AddressFieldWithScan(
                  controller: addressCtrl,
                  labelText: 'Indirizzo visita',
                  onScanned: () => setLocal(() {}),
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Data e ora'),
                  subtitle: Text(_formatDateTime(scheduled)),
                  trailing: IconButton(
                    icon: const Icon(Icons.schedule),
                    onPressed: () async {
                      final picked = await pickFieldVisitDateAndTime(
                        ctx,
                        initial: scheduled,
                      );
                      if (picked == null) return;
                      setLocal(() => scheduled = picked);
                    },
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
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Aggiungi in agenda'),
          ),
        ],
      ),
    ),
  );

  final addressText = addressCtrl.text;
  addressCtrl.dispose();
  if (ok != true || !context.mounted) return false;

  try {
    await FieldVisitService.importFromCalculation(
      calculation: calculation,
      calculationId: calculationId,
      scheduledAt: scheduled,
      address: addressText,
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

String _formatDateTime(DateTime value) {
  final d = value.day.toString().padLeft(2, '0');
  final m = value.month.toString().padLeft(2, '0');
  final h = value.hour.toString().padLeft(2, '0');
  final min = value.minute.toString().padLeft(2, '0');
  return '$d/$m/${value.year} $h:$min';
}
