import 'package:flutter/material.dart';

import '../layout/credit_calc_page_host.dart';
import '../nav/credit_calc_nav.dart';

import 'balance_write_off_page.dart';
import 'standard_repayment_plan_page.dart';

class DevelopPage extends StatelessWidget {
  const DevelopPage({super.key});

  @override
  Widget build(BuildContext context) {
    const items = [
      'Piano di rientro',
      'Saldo e stralcio',
    ];

    return wrapCreditCalcPage(
      pageTitle: 'Sviluppa',
      current: CreditCalcNavItem.develop,
      body: Card(
        child: ListView.separated(
          padding: const EdgeInsets.all(8),
          itemCount: items.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, index) {
            return ListTile(
              leading: const Icon(Icons.chevron_right),
              title: Text(items[index]),
              onTap: () {
                final title = items[index];
                final page = title == 'Piano di rientro'
                    ? const StandardRepaymentPlanPage()
                    : const BalanceWriteOffPage();
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => page),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
