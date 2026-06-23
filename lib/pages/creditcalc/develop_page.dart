import 'package:credit_calc_core/credit_calc_core.dart' hide DevelopPage;
import 'package:flutter/material.dart';

import 'itinerary/itinerary_hub_page.dart';

class DevelopPage extends StatelessWidget {
  const DevelopPage({super.key});

  @override
  Widget build(BuildContext context) {
    const items = [
      'Piano di rientro',
      'Saldo e stralcio',
      'Riscontro backoffice',
      'Itinerario e mappa',
      'Calcolatrice',
    ];

    return wrapCreditCalcPage(
      pageTitle: 'Sviluppa',
      current: CreditCalcNavItem.develop,
      body: Card(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var index = 0; index < items.length; index++) ...[
              if (index > 0) const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.chevron_right),
                title: Text(items[index]),
                onTap: () {
                  final title = items[index];
                  final Widget page;
                  if (title == 'Piano di rientro') {
                    page = const StandardRepaymentPlanPage();
                  } else if (title == 'Saldo e stralcio') {
                    page = const BalanceWriteOffPage();
                  } else if (title == 'Riscontro backoffice') {
                    page = const BackofficePendingPlansPage();
                  } else if (title == 'Calcolatrice') {
                    page = const ClassicCalculatorPage();
                  } else {
                    page = const ItineraryHubPage();
                  }
                  Navigator.of(context, rootNavigator: true).push(
                    MaterialPageRoute(builder: (_) => page),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}
