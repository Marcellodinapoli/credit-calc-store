import 'package:credit_calc_core/credit_calc_core.dart';
import 'package:flutter/material.dart';

import '../../../models/field_reminder.dart';
import '../../../models/field_visit.dart';
import '../../../services/field_reminder_service.dart';
import '../../../services/field_visit_service.dart';
import '../../../services/installment_monitor_service.dart';
import '../../../widgets/itinerary_day_summary_card.dart';
import '../../../widgets/itinerary_notifications_card.dart';
import 'activities_page.dart';
import 'itinerary_page_shell.dart';
import 'practice_agenda_page.dart';
import 'reminders_page.dart';
import 'territory_map_page.dart';
import 'visit_history_page.dart';

class ItineraryHubPage extends StatelessWidget {
  const ItineraryHubPage({super.key});

  void _open(BuildContext context, String sectionKey, Widget page) {
    pushSectionOccupancy<void>(
      context,
      sectionKey: sectionKey,
      child: page,
    );
  }

  @override
  Widget build(BuildContext context) {
    const shell = ItineraryPageShell();

    return shell.primary(
      pageTitle: 'Itinerario',
      body: ListView(
        padding: ItineraryPageShell.listPadding(context),
        children: [
          const Text(
            'Organizza il lavoro sul territorio: appuntamenti, attività, promemoria '
            'e pianificazione geografica sincronizzati con il tuo account.',
            style: TextStyle(color: Colors.black54, height: 1.45),
          ),
          const SizedBox(height: 16),
          const ItineraryDaySummaryCard(),
          const SizedBox(height: 16),
          const ItineraryNotificationsCard(),
          const SizedBox(height: 16),
          Card(
            child: StreamBuilder<List<FieldVisit>>(
              stream: FieldVisitService.watchAllForUser(),
              builder: (context, visitsSnap) {
                final badgeCount =
                    InstallmentMonitorService.upcomingDomiciliareCount(
                  visitsSnap.data ?? const [],
                );
                return ListTile(
                  leading: Badge(
                    isLabelVisible: badgeCount > 0,
                    label: Text(badgeCount > 99 ? '99+' : '$badgeCount'),
                    backgroundColor: Colors.red.shade700,
                    child: const Icon(Icons.event, color: Color(0xFF00B0FF)),
                  ),
                  title: const Text('Appuntamenti'),
                  subtitle: const Text(
                    'Agenda giornaliera: visite, import da provvigioni e stato pratiche.',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _open(
                    context,
                    'itinerary:appointments',
                    const PracticeAgendaPage(
                      pageTitle: 'Appuntamenti',
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.checklist, color: Color(0xFF00B0FF)),
              title: const Text('Attività'),
              subtitle: const Text(
                'Compiti e follow-up da completare, con scadenza opzionale.',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _open(context, 'itinerary:activities', const ActivitiesPage()),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: StreamBuilder<List<FieldReminder>>(
              stream: FieldReminderService.watchUpcoming(),
              builder: (context, remindersSnap) {
                final badgeCount =
                    InstallmentMonitorService.badgeCountFromReminders(
                  remindersSnap.data ?? const [],
                );
                return ListTile(
                  leading: Badge(
                    isLabelVisible: badgeCount > 0,
                    label: Text(badgeCount > 99 ? '99+' : '$badgeCount'),
                    backgroundColor: Colors.red.shade700,
                    child: const Icon(
                      Icons.alarm,
                      color: Color(0xFF00B0FF),
                    ),
                  ),
                  title: const Text('Promemoria'),
                  subtitle: const Text(
                    'Avvisi programmati per richiami e scadenze importanti.',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _open(context, 'itinerary:reminders', const RemindersPage()),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.map_outlined, color: Color(0xFF00B0FF)),
              title: const Text('Pianificazione territoriale'),
              subtitle: const Text(
                'Mappa OpenStreetMap con visite geolocalizzate e percorsi.',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _open(
                context,
                'itinerary:map',
                const TerritoryMapPage(
                  pageTitle: 'Pianificazione territoriale',
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.history, color: Color(0xFF00B0FF)),
              title: const Text('Storico visite'),
              subtitle: const Text(
                'Riepilogo per mese e zona territoriale.',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _open(context, 'itinerary:history', const VisitHistoryPage()),
            ),
          ),
        ],
      ),
    );
  }
}
