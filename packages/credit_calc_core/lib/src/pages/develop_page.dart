import 'package:flutter/material.dart';

import '../layout/credit_calc_page_host.dart';
import '../nav/credit_calc_nav.dart';

import 'backoffice_pending_plans_page.dart';
import 'balance_write_off_page.dart';
import 'standard_repayment_plan_page.dart';

class _DevelopMenuItem {
  const _DevelopMenuItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.page,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Widget page;
}

class DevelopPage extends StatelessWidget {
  const DevelopPage({super.key});

  static const _menuItems = [
    _DevelopMenuItem(
      title: 'Piano di rientro',
      subtitle: 'Simula rate e scadenze per il rientro del debito.',
      icon: Icons.calendar_month_outlined,
      page: StandardRepaymentPlanPage(),
    ),
    _DevelopMenuItem(
      title: 'Saldo e stralcio',
      subtitle: 'Valuta proposte di saldo e stralcio con confronto scenari.',
      icon: Icons.handshake_outlined,
      page: BalanceWriteOffPage(),
    ),
    _DevelopMenuItem(
      title: 'Riscontro backoffice',
      subtitle: 'Piani sviluppati in attesa di approvazione o incasso.',
      icon: Icons.fact_check_outlined,
      page: BackofficePendingPlansPage(),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return wrapCreditCalcPage(
      pageTitle: 'Sviluppa',
      current: CreditCalcNavItem.develop,
      body: ListView(
        children: [
          for (var i = 0; i < _menuItems.length; i++) ...[
            if (i > 0) const SizedBox(height: 12),
            Card(
              child: ListTile(
                leading: Icon(_menuItems[i].icon),
                title: Text(_menuItems[i].title),
                subtitle: Text(_menuItems[i].subtitle),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.of(context, rootNavigator: true).push(
                    MaterialPageRoute(builder: (_) => _menuItems[i].page),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}
