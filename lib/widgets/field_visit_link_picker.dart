import 'package:flutter/material.dart';

import '../models/field_visit.dart';
import '../services/field_visit_service.dart';

class FieldVisitLinkPicker extends StatefulWidget {
  const FieldVisitLinkPicker({
    super.key,
    required this.value,
    required this.onChanged,
    this.day,
  });

  final String? value;
  final ValueChanged<String?> onChanged;
  final DateTime? day;

  @override
  State<FieldVisitLinkPicker> createState() => _FieldVisitLinkPickerState();
}

class _FieldVisitLinkPickerState extends State<FieldVisitLinkPicker> {
  late Future<List<FieldVisit>> _visitsFuture;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final day = widget.day ?? DateTime.now();
    _visitsFuture = FieldVisitService.watchForDay(day).first;
  }

  String _visitLabel(FieldVisit visit) {
    final name =
        visit.companyName.isEmpty ? 'Visita' : visit.companyName.trim();
    final time =
        '${visit.scheduledAt.hour.toString().padLeft(2, '0')}:'
        '${visit.scheduledAt.minute.toString().padLeft(2, '0')}';
    return '$time · $name';
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<FieldVisit>>(
      future: _visitsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LinearProgressIndicator();
        }

        final visits = (snapshot.data ?? [])
            .where((v) => v.status != FieldVisitStatus.cancelled)
            .toList();

        if (visits.isEmpty) {
          return const Text(
            'Nessun appuntamento oggi da collegare.',
            style: TextStyle(color: Colors.black54, fontSize: 13),
          );
        }

        return DropdownButtonFormField<String?>(
          value: widget.value,
          decoration: const InputDecoration(
            labelText: 'Appuntamento collegato (opzionale)',
            border: OutlineInputBorder(),
          ),
          items: [
            const DropdownMenuItem<String?>(
              value: null,
              child: Text('Nessun collegamento'),
            ),
            for (final visit in visits)
              DropdownMenuItem<String?>(
                value: visit.id,
                child: Text(_visitLabel(visit)),
              ),
          ],
          onChanged: widget.onChanged,
        );
      },
    );
  }
}
