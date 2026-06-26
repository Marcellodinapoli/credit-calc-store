import 'package:credit_calc_core/credit_calc_core.dart';
import 'package:flutter/material.dart';

class ToolsPage extends StatelessWidget {
  const ToolsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return wrapCreditCalcPage(
      pageTitle: 'Strumenti',
      current: CreditCalcNavItem.tools,
      body: const Card(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Ricerca normativa e Analisi telefonata sono in Sviluppa.',
            style: TextStyle(color: Colors.black54, height: 1.45),
          ),
        ),
      ),
    );
  }
}
