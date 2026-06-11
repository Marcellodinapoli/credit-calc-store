import 'package:credit_calc_core/credit_calc_core.dart'
    hide BalanceWriteOffPage, DevelopPage, StandardRepaymentPlanPage;
import 'package:flutter/material.dart';

import 'itinerary/itinerary_hub_page.dart';
import 'balance_write_off_page.dart';
import 'standard_repayment_plan_page.dart';

class DevelopPage extends StatelessWidget {
  const DevelopPage({super.key});

  @override
  Widget build(BuildContext context) {
    const items = [
      'Piano di rientro',
      'Saldo e stralcio',
      'Itinerario e mappa',
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
                final Widget page;
                if (title == 'Piano di rientro') {
                  page = const StandardRepaymentPlanPage();
                } else if (title == 'Saldo e stralcio') {
                  page = const BalanceWriteOffPage();
                } else {
                  page = const ItineraryHubPage();
                }
                Navigator.of(context, rootNavigator: true).push(
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
