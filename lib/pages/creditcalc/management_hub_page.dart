import 'package:credit_calc_core/credit_calc_core.dart' hide ProjectColors;
import 'package:flutter/material.dart';

import '../../core/maintenance_service.dart';
import '../../core/theme/project_colors.dart';
import '../../models/field_reminder.dart';
import '../../models/field_visit.dart';
import '../../services/field_reminder_service.dart';
import '../../services/field_visit_service.dart';
import '../../services/gestione_menu_badge_service.dart';
import '../../services/installment_monitor_service.dart';
import '../../widgets/management_section_intro.dart';
import '../area/personal_area_shell.dart';
import 'installment_monitor_page.dart';
import 'itinerary/activities_page.dart';
import 'itinerary/practice_agenda_page.dart';
import 'itinerary/reminders_page.dart';
import 'itinerary/territory_map_page.dart';
import 'itinerary/visit_history_page.dart';

class ManagementHubPage extends StatelessWidget {
  const ManagementHubPage({super.key});

  Future<void> _open(BuildContext context, Widget page) async {
    if (!context.mounted) return;
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(builder: (_) => page),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PersonalAreaShell(
      pageTitle: 'Oggi',
      gestioneSection: true,
      gestioneBadgeKey: GestioneMenuBadgeKey.oggi,
      maintenanceSection: MaintenanceService.creditCalc,
      body: StreamBuilder<List<FieldReminder>>(
        stream: FieldReminderService.watchUpcoming(),
        builder: (context, remindersSnap) {
          return StreamBuilder<List<FieldVisit>>(
            stream: FieldVisitService.watchAllForUser(),
            builder: (context, visitsSnap) {
              final reminders = remindersSnap.data ?? const [];
              final visits = visitsSnap.data ?? const [];
              final rateizzoBadge = InstallmentMonitorService.upcomingAlertCount(
                reminders: reminders,
                visits: visits,
              );
              final promemoriaBadge =
                  InstallmentMonitorService.badgeCountFromReminders(reminders);
              final appuntamentiBadge =
                  InstallmentMonitorService.upcomingDomiciliareCount(visits);

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const Text(
                    'Riscontri backoffice, monitoraggio rate, appuntamenti '
                    'e attività sul territorio.',
                    style: TextStyle(color: Colors.black54, height: 1.45),
                  ),
                  const SizedBox(height: 16),
                  const ManagementSectionIntro(),
                  const SizedBox(height: 16),
                  Card(
                    child: Column(
                      children: [
                        ListTile(
                          leading: const Icon(
                            Icons.fact_check_outlined,
                            color: ProjectColors.area,
                          ),
                          title: const Text('Riscontro backoffice'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => _open(
                            context,
                            const BackofficePendingPlansPage(),
                          ),
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: Badge(
                            isLabelVisible: rateizzoBadge > 0,
                            label: Text(
                              rateizzoBadge > 99 ? '99+' : '$rateizzoBadge',
                            ),
                            backgroundColor: Colors.red.shade700,
                            child: const Icon(
                              Icons.calendar_month_outlined,
                              color: ProjectColors.area,
                            ),
                          ),
                          title: const Text('Monitoraggio rata'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => _open(
                            context,
                            const InstallmentMonitorPage(personalArea: true),
                          ),
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: Badge(
                            isLabelVisible: appuntamentiBadge > 0,
                            label: Text(
                              appuntamentiBadge > 99
                                  ? '99+'
                                  : '$appuntamentiBadge',
                            ),
                            backgroundColor: Colors.red.shade700,
                            child: const Icon(
                              Icons.event,
                              color: ProjectColors.area,
                            ),
                          ),
                          title: const Text('Appuntamenti'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => _open(
                            context,
                            const PracticeAgendaPage(
                              pageTitle: 'Appuntamenti',
                              personalArea: true,
                            ),
                          ),
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: const Icon(
                            Icons.checklist,
                            color: ProjectColors.area,
                          ),
                          title: const Text('Attività'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => _open(
                            context,
                            const ActivitiesPage(personalArea: true),
                          ),
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: Badge(
                            isLabelVisible: promemoriaBadge > 0,
                            label: Text(
                              promemoriaBadge > 99 ? '99+' : '$promemoriaBadge',
                            ),
                            backgroundColor: Colors.red.shade700,
                            child: const Icon(
                              Icons.alarm,
                              color: ProjectColors.area,
                            ),
                          ),
                          title: const Text('Promemoria'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => _open(
                            context,
                            const RemindersPage(personalArea: true),
                          ),
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: const Icon(
                            Icons.map_outlined,
                            color: ProjectColors.area,
                          ),
                          title: const Text('Pianificazione'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => _open(
                            context,
                            const TerritoryMapPage(
                              pageTitle: 'Pianificazione',
                              personalArea: true,
                            ),
                          ),
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: const Icon(
                            Icons.history,
                            color: ProjectColors.area,
                          ),
                          title: const Text('Storico visite'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => _open(
                            context,
                            const VisitHistoryPage(personalArea: true),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
