import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:credit_calc_core/credit_calc_core.dart'
    hide CommissionCollectionsHelper;
import 'package:flutter/material.dart';

import 'commission_collections_shared.dart';
import 'commission_statistics_section.dart';

/// Statistiche provvigioni in impaginazione secondaria.
class CommissionStatisticsPage extends StatelessWidget {
  const CommissionStatisticsPage({super.key});

  Future<void> _openInsertCommission(BuildContext context) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => const CommissionEntryPage(),
      ),
    );
    if (saved == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Provvigione inserita correttamente.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return wrapCreditCalcPage(
      secondary: true,
      pageTitle: 'Statistiche provvigioni',
      current: CreditCalcNavItem.commissions,
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirestoreUserScope.userCalculations().snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Impossibile caricare le statistiche.\n${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.red.shade700),
                ),
              ),
            );
          }

          final docs =
              CommissionCollectionsHelper.commissionDocs(snapshot.data);

          return ListView(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
            children: [
              CommissionStatisticsSection(docs: docs),
              const SizedBox(height: 12),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.edit_note),
                  title: const Text('Inserisci provvigioni'),
                  subtitle: const Text(
                    'Registra un nuovo incasso e le relative provvigioni.',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _openInsertCommission(context),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
