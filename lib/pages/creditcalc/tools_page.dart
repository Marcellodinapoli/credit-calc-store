import 'package:credit_calc_core/credit_calc_core.dart';
import 'package:flutter/material.dart';

import 'normative_search_page.dart';
import 'phone_call_analysis_page.dart';

class ToolsPage extends StatelessWidget {
  const ToolsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return wrapCreditCalcPage(
      pageTitle: 'Strumenti',
      current: CreditCalcNavItem.tools,
      body: Card(
        child: ListView.separated(
          padding: const EdgeInsets.all(8),
          itemCount: 2,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, index) {
            return switch (index) {
              0 => ListTile(
                  leading: const Icon(Icons.balance_outlined),
                  title: const Text('Ricerca normativa'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _open(context, const NormativeSearchPage()),
                ),
              1 => ListTile(
                  leading: const Icon(Icons.call_outlined),
                  title: const Text('Analisi telefonata'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _open(context, const PhoneCallAnalysisPage()),
                ),
              _ => const SizedBox.shrink(),
            };
          },
        ),
      ),
    );
  }

  void _open(BuildContext context, Widget page) {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(builder: (_) => page),
    );
  }
}
