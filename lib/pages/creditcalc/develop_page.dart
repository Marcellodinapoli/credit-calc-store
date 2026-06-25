import 'package:credit_calc_core/credit_calc_core.dart'
    hide BalanceWriteOffPage, DevelopPage, StandardRepaymentPlanPage;
import 'package:flutter/material.dart';

import 'balance_write_off_page.dart';
import 'debtor_contact_page.dart';
import 'standard_repayment_plan_page.dart';

class DevelopPage extends StatelessWidget {
  const DevelopPage({super.key});

  static const _menuItems = [
    'Piano di rientro',
    'Saldo e stralcio',
    'WhatsApp e email',
    'Calcolatrice',
  ];

  @override
  Widget build(BuildContext context) {
    return wrapCreditCalcPage(
      pageTitle: 'Sviluppa',
      current: CreditCalcNavItem.develop,
      body: Card(
        child: ListView.separated(
          padding: const EdgeInsets.all(8),
          itemCount: _menuItems.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final title = _menuItems[index];
            return ListTile(
              leading: const Icon(Icons.chevron_right),
              title: Text(title),
              onTap: () => _openItem(context, title),
            );
          },
        ),
      ),
    );
  }

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
    } else if (title == 'WhatsApp e email') {
      page = const DebtorContactPage();
    } else {
      page = const ClassicCalculatorPage();
    }

    if (!context.mounted) return;
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(builder: (_) => page),
    );
  }
}
