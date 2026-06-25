import 'package:flutter/material.dart';

import '../layout/credit_calc_page_host.dart';
import '../nav/credit_calc_nav.dart';

import 'commission_creditor_data_access.dart';
import 'creditor_detail_page.dart';
import 'creditors_list_data_access.dart';

class CreditorsPage extends StatelessWidget {
  const CreditorsPage({super.key});

  Future<Object?> _openCreditorForm(
    BuildContext context, {
    required String creditorId,
    required String name,
    String notes = '',
    int maxAge = 80,
  }) {
    return showDialog<Object?>(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (ctx) {
        return Dialog.fullscreen(
          child: CreditorDetailPage(
            creditorId: creditorId,
            name: name,
            notes: notes,
            maxAge: maxAge,
          ),
        );
      },
    );
  }

  void _showSavedSnackBar(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Impostazioni creditore salvate.')),
    );
  }

  void _showDeletedSnackBar(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Creditore eliminato.')),
    );
  }

  void _handleCreditorFormResult(BuildContext context, Object? result) {
    if (!context.mounted) return;
    if (result == true) {
      _showSavedSnackBar(context);
    } else if (result == 'deleted') {
      _showDeletedSnackBar(context);
    }
  }

  Future<void> _addCreditor(BuildContext context, int currentCount) async {
    final label = 'Creditore ${currentCount + 1}';
    final docId = CreditorsListDataAccess.instance.newCreditorId();

    if (!context.mounted) return;

    try {
      final result = await _openCreditorForm(
        context,
        creditorId: docId,
        name: label,
        maxAge: 80,
      );
      if (context.mounted) _handleCreditorFormResult(context, result);
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Impossibile aprire il form creditore.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return wrapCreditCalcPage(
      pageTitle: 'Lista creditori',
      current: CreditCalcNavItem.creditors,
      body: StreamBuilder<List<CreditorRecord>>(
        stream: CreditorsListDataAccess.instance.watchCreditors(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Errore nel caricamento creditori:\n${snapshot.error}',
                textAlign: TextAlign.center,
              ),
            );
          }

          final records = snapshot.data ?? const [];

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: 10,
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Chip(label: Text('Totale creditori: ${records.length}')),
                  ElevatedButton.icon(
                    onPressed: () => _addCreditor(context, records.length),
                    icon: const Icon(Icons.add),
                    label: const Text('Aggiungi'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: Card(
                  child: records.isEmpty
                      ? const Center(
                          child: Text(
                            'Nessun creditore presente.\n'
                            'Premi Aggiungi per registrarne uno.',
                            textAlign: TextAlign.center,
                          ),
                        )
                      : ListView.separated(
                          itemCount: records.length,
                          separatorBuilder: (_, __) =>
                              const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final record = records[index];
                            final data = record.data;
                            final name = (data['name'] ?? '').toString();
                            final notes = (data['notes'] ?? '').toString();
                            final maxAgeRaw = data['maxAge'];
                            final maxAge = maxAgeRaw is int
                                ? maxAgeRaw
                                : int.tryParse(
                                        maxAgeRaw?.toString() ?? '') ??
                                    80;
                            final label = creditorDisplayLabel(index, data);

                            return ListTile(
                              title: Text(label),
                              subtitle: const Text('Impostazioni creditore'),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () async {
                                final result = await _openCreditorForm(
                                  context,
                                  creditorId: record.id,
                                  name: label,
                                  notes: notes,
                                  maxAge: maxAge,
                                );
                                if (context.mounted) {
                                  _handleCreditorFormResult(context, result);
                                }
                              },
                            );
                          },
                        ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
