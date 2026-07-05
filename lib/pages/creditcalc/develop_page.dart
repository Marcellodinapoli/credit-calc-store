import 'package:credit_calc_core/credit_calc_core.dart' hide DevelopPage;
import 'package:flutter/material.dart';

import '../../models/field_reminder.dart';
import '../../models/field_visit.dart';
import '../../services/field_reminder_service.dart';
import '../../services/field_visit_service.dart';
import '../../services/installment_monitor_service.dart';
import 'building_residents_lookup_page.dart';
import 'debtor_contact_page.dart';
import 'installment_monitor_page.dart';
import 'normative_search_page.dart';
import 'phone_call_analysis_page.dart';

class _DevelopMenuItem {
  const _DevelopMenuItem({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final IconData icon;
}

class DevelopPage extends StatelessWidget {
  const DevelopPage({super.key});

  static const _menuItems = [
    _DevelopMenuItem(
      title: 'Piano di rientro',
      subtitle: 'Simula rate e scadenze per il rientro del debito.',
      icon: Icons.calendar_month_outlined,
    ),
    _DevelopMenuItem(
      title: 'Saldo e stralcio',
      subtitle: 'Valuta proposte di saldo e stralcio con confronto scenari.',
      icon: Icons.handshake_outlined,
    ),
    _DevelopMenuItem(
      title: 'Riscontro backoffice',
      subtitle: 'Esiti e piani in attesa di valutazione dal backoffice.',
      icon: Icons.fact_check_outlined,
    ),
    _DevelopMenuItem(
      title: 'Monitoraggio rata',
      subtitle: 'Scadenze PDR e collegamento con l\'agenda.',
      icon: Icons.calendar_month_outlined,
    ),
    _DevelopMenuItem(
      title: 'WhatsApp e email',
      subtitle: 'Modelli di messaggio per contattare il debitore.',
      icon: Icons.chat_outlined,
    ),
    _DevelopMenuItem(
      title: 'Calcolatrice',
      subtitle: 'Calcoli rapidi durante la trattativa.',
      icon: Icons.calculate_outlined,
    ),
    _DevelopMenuItem(
      title: 'Ricerca per indirizzo',
      subtitle:
          'Nominativi da Pagine Bianche e motori web pubblici al civico.',
      icon: Icons.apartment_outlined,
    ),
    _DevelopMenuItem(
      title: 'Ricerca normativa',
      subtitle: 'Domande su normativa e recupero crediti con risposta AI.',
      icon: Icons.gavel_outlined,
    ),
    _DevelopMenuItem(
      title: 'Analisi telefonata',
      subtitle: 'Suggerimenti e leve negoziali sulla base della pratica.',
      icon: Icons.phone_in_talk_outlined,
    ),
  ];

  static int _backofficeIncassiBadgeCount(List<BackofficePendingPlan> plans) =>
      plans.where((plan) => !plan.hasCommissionExport).length;

  Widget _leadingIcon(
    _DevelopMenuItem item, {
    required int backofficeIncassiBadgeCount,
    required int rateizzoBadgeCount,
  }) {
    int? badgeCount;
    if (item.title == 'Riscontro backoffice' && backofficeIncassiBadgeCount > 0) {
      badgeCount = backofficeIncassiBadgeCount;
    } else if (item.title == 'Monitoraggio rata' && rateizzoBadgeCount > 0) {
      badgeCount = rateizzoBadgeCount;
    }

    if (badgeCount == null) {
      return Icon(item.icon);
    }

    return Badge(
      isLabelVisible: true,
      label: Text(badgeCount > 99 ? '99+' : '$badgeCount'),
      backgroundColor: Colors.red.shade700,
      child: Icon(item.icon),
    );
  }

  @override
  Widget build(BuildContext context) {
    return wrapCreditCalcPage(
      pageTitle: 'Sviluppa',
      current: CreditCalcNavItem.develop,
      body: StreamBuilder<List<BackofficePendingPlan>>(
        stream: BackofficePendingPlanService.watchAll(),
        builder: (context, snapshot) {
          final backofficeIncassiBadgeCount = _backofficeIncassiBadgeCount(
            snapshot.data ?? const [],
          );

          return StreamBuilder<List<FieldReminder>>(
            stream: FieldReminderService.watchUpcoming(),
            builder: (context, remindersSnap) {
              return StreamBuilder<List<FieldVisit>>(
                stream: FieldVisitService.watchAllForUser(),
                builder: (context, visitsSnap) {
                  final rateizzoBadge =
                      InstallmentMonitorService.upcomingAlertCount(
                    reminders: remindersSnap.data ?? const [],
                    visits: visitsSnap.data ?? const [],
                  );

                  return ListView(
                    children: [
                      for (var i = 0; i < _menuItems.length; i++) ...[
                        if (i > 0) const SizedBox(height: 12),
                        Card(
                          child: ListTile(
                            leading: _leadingIcon(
                              _menuItems[i],
                              backofficeIncassiBadgeCount:
                                  backofficeIncassiBadgeCount,
                              rateizzoBadgeCount: rateizzoBadge,
                            ),
                            title: Text(_menuItems[i].title),
                            subtitle: Text(_menuItems[i].subtitle),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => _openItem(context, _menuItems[i].title),
                          ),
                        ),
                      ],
                    ],
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  static String? _sectionKeyForTitle(String title) => switch (title) {
        'Piano di rientro' => 'repayment_plan',
        'Saldo e stralcio' => 'balance_write_off',
        'Riscontro backoffice' => 'develop:backoffice',
        'Monitoraggio rata' => 'develop:installment_monitor',
        'WhatsApp e email' => 'develop:debtor_contact',
        'Ricerca per indirizzo' => 'develop:building_lookup',
        'Ricerca normativa' => 'develop:normative_search',
        'Analisi telefonata' => 'develop:phone_analysis',
        'Calcolatrice' => 'develop:calculator',
        _ => null,
      };

  Future<void> _openItem(BuildContext context, String title) async {
    final Widget page;
    if (title == 'Piano di rientro') {
      page = StandardRepaymentPlanPage(
        key: ValueKey(DateTime.now().microsecondsSinceEpoch),
      );
    } else if (title == 'Saldo e stralcio') {
      page = BalanceWriteOffPage(
        key: ValueKey(DateTime.now().microsecondsSinceEpoch),
      );
    } else if (title == 'Riscontro backoffice') {
      page = const BackofficePendingPlansPage();
    } else if (title == 'Monitoraggio rata') {
      page = const InstallmentMonitorPage();
    } else if (title == 'WhatsApp e email') {
      page = const DebtorContactPage();
    } else if (title == 'Ricerca per indirizzo') {
      page = const BuildingResidentsLookupPage();
    } else if (title == 'Ricerca normativa') {
      page = const NormativeSearchPage();
    } else if (title == 'Analisi telefonata') {
      page = const PhoneCallAnalysisPage();
    } else if (title == 'Calcolatrice') {
      page = const ClassicCalculatorPage();
    } else {
      return;
    }

    if (!context.mounted) return;
    final sectionKey = _sectionKeyForTitle(title);
    if (sectionKey == null) return;
    await pushSectionOccupancy<void>(
      context,
      sectionKey: sectionKey,
      rootNavigator: true,
      child: page,
    );
  }
}
