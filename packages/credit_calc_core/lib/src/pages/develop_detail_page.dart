import 'package:flutter/material.dart';

import '../layout/credit_calc_page_host.dart';
import '../nav/credit_calc_nav.dart';


class DevelopDetailPage extends StatelessWidget {
  final String title;

  const DevelopDetailPage({
    super.key,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return wrapCreditCalcPage(
      secondary: true,
      pageTitle: title,
      current: CreditCalcNavItem.develop,
      body: ListView(
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Area operativa pronta per lo sviluppo del flusso dedicato. '
                    'In questa sezione potrai inserire dati, simulare e salvare il risultato.',
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Funzione pronta per configurazione avanzata.'),
                        ),
                      );
                    },
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Avvia'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
