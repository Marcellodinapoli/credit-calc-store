import 'package:flutter/material.dart';

import '../../../widgets/itinerary_day_summary_card.dart';
import '../../../widgets/itinerary_notifications_card.dart';
import 'activities_page.dart';
import 'itinerary_page_shell.dart';
import 'practice_agenda_page.dart';
import 'reminders_page.dart';
import 'territory_map_page.dart';
import 'visit_history_page.dart';

class ItineraryHubPage extends StatelessWidget {
  const ItineraryHubPage({super.key, this.personalArea = false});

  final bool personalArea;

  void _open(BuildContext context, Widget page) {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(builder: (_) => page),
    );
  }

  @override
  Widget build(BuildContext context) {
    final shell = ItineraryPageShell(personalArea: personalArea);

    return shell.primary(
      pageTitle: 'Itinerario',
      body: ListView(
        padding: const EdgeInsets.all(16),
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
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.event, color: Color(0xFF00B0FF)),
                  title: const Text('Appuntamenti'),
                  subtitle: const Text(
                    'Agenda giornaliera: visite, import da provvigioni e stato pratiche.',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _open(
                    context,
                    PracticeAgendaPage(
                      personalArea: personalArea,
                      pageTitle: 'Appuntamenti',
                    ),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.checklist, color: Color(0xFF00B0FF)),
                  title: const Text('Attività'),
                  subtitle: const Text(
                    'Compiti e follow-up da completare, con scadenza opzionale.',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _open(
                    context,
                    ActivitiesPage(personalArea: personalArea),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.alarm, color: Color(0xFF00B0FF)),
                  title: const Text('Promemoria'),
                  subtitle: const Text(
                    'Avvisi programmati per richiami e scadenze importanti.',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _open(
                    context,
                    RemindersPage(personalArea: personalArea),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.map_outlined, color: Color(0xFF00B0FF)),
                  title: const Text('Pianificazione territoriale'),
                  subtitle: const Text(
                    'Mappa OpenStreetMap con visite geolocalizzate e percorsi.',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _open(
                    context,
                    TerritoryMapPage(
                      personalArea: personalArea,
                      pageTitle: 'Pianificazione territoriale',
                    ),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.history, color: Color(0xFF00B0FF)),
                  title: const Text('Storico visite'),
                  subtitle: const Text(
                    'Riepilogo per mese e zona territoriale.',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _open(
                    context,
                    VisitHistoryPage(personalArea: personalArea),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
