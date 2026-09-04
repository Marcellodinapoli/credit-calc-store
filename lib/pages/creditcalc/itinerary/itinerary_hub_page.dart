import 'package:credit_calc_core/credit_calc_core.dart';
import 'package:flutter/material.dart';

import '../../../models/field_reminder.dart';
import '../../../models/field_visit.dart';
import '../../../services/field_reminder_service.dart';
import '../../../services/field_visit_service.dart';
import '../../../services/installment_monitor_service.dart';
import '../../../services/itinerary_deep_link.dart';
import '../../../services/itinerary_nav_badge_notifier.dart';
import '../../../widgets/itinerary_day_summary_card.dart';
import '../../../widgets/itinerary_notifications_card.dart';
import 'activities_page.dart';
import 'affido_pratiche_page.dart';
import 'itinerary_page_shell.dart';
import 'practice_agenda_page.dart';
import 'reminders_page.dart';
import 'territory_map_page.dart';
import 'visit_history_page.dart';

class ItineraryHubPage extends StatefulWidget {
  const ItineraryHubPage({super.key});

  @override
  State<ItineraryHubPage> createState() => _ItineraryHubPageState();
}

class _ItineraryHubPageState extends State<ItineraryHubPage> {
  @override
  void initState() {
    super.initState();
    ItineraryDeepLink.request.addListener(_onDeepLink);
    WidgetsBinding.instance.addPostFrameCallback((_) => _onDeepLink());
  }

  @override
  void dispose() {
    ItineraryDeepLink.request.removeListener(_onDeepLink);
    super.dispose();
  }

  void _onDeepLink() {
    final req = ItineraryDeepLink.request.value;
    if (req == null || !mounted) return;
    ItineraryDeepLink.clear();
    switch (req.target) {
      case ItineraryDeepLinkTarget.appointments:
        _openAppointments(visitId: req.id);
      case ItineraryDeepLinkTarget.reminders:
        _openReminders(reminderId: req.id);
    }
  }

  Future<void> _openAppointments({String? visitId}) async {
    ItineraryNavBadgeNotifier.instance.clearAppointments();
    if (!mounted) return;
    await pushSectionOccupancy<void>(
      context,
      sectionKey: 'itinerary:appointments',
      child: PracticeAgendaPage(
        pageTitle: 'Appuntamenti',
        focusVisitId: visitId,
      ),
    );
  }

  Future<void> _openReminders({String? reminderId}) async {
    ItineraryNavBadgeNotifier.instance.clearReminders();
    if (!mounted) return;
    await pushSectionOccupancy<void>(
      context,
      sectionKey: 'itinerary:reminders',
      child: RemindersPage(focusReminderId: reminderId),
    );
  }

  void _open(BuildContext context, String sectionKey, Widget page) {
    if (sectionKey == 'itinerary:appointments') {
      ItineraryNavBadgeNotifier.instance.clearAppointments();
    } else if (sectionKey == 'itinerary:reminders') {
      ItineraryNavBadgeNotifier.instance.clearReminders();
    }
    pushSectionOccupancy<void>(
      context,
      sectionKey: sectionKey,
      child: page,
    );
  }

  @override
  Widget build(BuildContext context) {
    const shell = ItineraryPageShell();
    final badges = ItineraryNavBadgeNotifier.instance;

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
                final dataCount =
                    InstallmentMonitorService.upcomingDomiciliareCount(
                  visitsSnap.data ?? const [],
                );
                return ValueListenableBuilder<bool>(
                  valueListenable: badges.appointmentsPending,
                  builder: (context, alert, _) {
                    final show = dataCount > 0 || alert;
                    final label = dataCount > 0
                        ? (dataCount > 99 ? '99+' : '$dataCount')
                        : '!';
                    return ListTile(
                      leading: Badge(
                        isLabelVisible: show,
                        label: Text(label),
                        backgroundColor: Colors.red.shade700,
                        child: const Icon(
                          Icons.event,
                          color: Color(0xFF00B0FF),
                        ),
                      ),
                      title: const Text('Appuntamenti'),
                      subtitle: const Text(
                        'Agenda giornaliera: visite, import da provvigioni e stato pratiche.',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _openAppointments(),
                    );
                  },
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
              onTap: () => _open(
                context,
                'itinerary:activities',
                const ActivitiesPage(),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: StreamBuilder<List<FieldReminder>>(
              stream: FieldReminderService.watchUpcoming(),
              builder: (context, remindersSnap) {
                final dataCount =
                    InstallmentMonitorService.badgeCountFromReminders(
                  remindersSnap.data ?? const [],
                );
                return ValueListenableBuilder<bool>(
                  valueListenable: badges.remindersPending,
                  builder: (context, alert, _) {
                    final show = dataCount > 0 || alert;
                    final label = dataCount > 0
                        ? (dataCount > 99 ? '99+' : '$dataCount')
                        : '!';
                    return ListTile(
                      leading: Badge(
                        isLabelVisible: show,
                        label: Text(label),
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
                      onTap: () => _openReminders(),
                    );
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.assignment_ind, color: Color(0xFF00B0FF)),
              title: const Text('Pratiche in affido'),
              subtitle: const Text(
                'Consulente esterno: apri pratiche del gestionale, note e codice scarico.',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _open(
                context,
                'itinerary:affido',
                const AffidoPratichePage(),
              ),
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
              onTap: () => _open(
                context,
                'itinerary:history',
                const VisitHistoryPage(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
