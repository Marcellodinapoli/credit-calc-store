import 'package:flutter/material.dart';

import '../models/field_activity.dart';
import '../models/field_reminder.dart';
import '../models/field_visit.dart';
import '../services/field_activity_service.dart';
import '../services/field_reminder_service.dart';
import '../services/field_visit_service.dart';

class ItineraryDaySummaryCard extends StatelessWidget {
  const ItineraryDaySummaryCard({super.key});

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();

    return Card(
      color: const Color(0xFFE8F4FD),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: StreamBuilder<List<FieldVisit>>(
          stream: FieldVisitService.watchForDay(today),
          builder: (context, visitsSnap) {
            return StreamBuilder<List<FieldActivity>>(
              stream: FieldActivityService.watchAll(),
              builder: (context, activitiesSnap) {
                return StreamBuilder<List<FieldReminder>>(
                  stream: FieldReminderService.watchUpcoming(),
                  builder: (context, remindersSnap) {
                    final visits = (visitsSnap.data ?? [])
                        .where((v) => v.status != FieldVisitStatus.cancelled)
                        .length;
                    final activities = (activitiesSnap.data ?? [])
                        .where((a) => !a.completed)
                        .length;
                    final reminders = (remindersSnap.data ?? []).where((r) {
                      final d = r.remindAt;
                      return d.year == today.year &&
                          d.month == today.month &&
                          d.day == today.day;
                    }).length;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Oggi',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _summaryLine(visits, activities, reminders),
                          style: const TextStyle(
                            color: Color(0xFF1565C0),
                            height: 1.4,
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }

  String _summaryLine(int visits, int activities, int reminders) {
    final parts = <String>[
      '$visits ${visits == 1 ? 'appuntamento' : 'appuntamenti'}',
      '$activities ${activities == 1 ? 'attività aperta' : 'attività aperte'}',
      '$reminders ${reminders == 1 ? 'promemoria' : 'promemoria'}',
    ];
    return parts.join(' · ');
  }
}
