import 'package:credit_calc_core/credit_calc_core.dart' hide DevelopPage;
import 'package:flutter/material.dart';

import 'debtor_contact_page.dart';
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
                onTap: () => _openItem(context, _menuItems[i].title),
              ),
            ),
          ],
        ],
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
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(builder: (_) => page),
    );
  }
}
