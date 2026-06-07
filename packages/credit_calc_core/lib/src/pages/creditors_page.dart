import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../core/firestore_user_scope.dart';
import '../layout/credit_calc_page_host.dart';
import '../nav/credit_calc_nav.dart';

import 'creditor_detail_page.dart';

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
    final docId =
        FirebaseFirestore.instance.collection('creditors').doc().id;

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

  String _listLabel(int index, String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return 'Creditore ${index + 1}';
    if (trimmed.toLowerCase().startsWith('creditore')) return trimmed;
    return 'Creditore ${index + 1}: $trimmed';
  }

  @override
  Widget build(BuildContext context) {
    return wrapCreditCalcPage(
      pageTitle: 'Lista creditori',
      current: CreditCalcNavItem.creditors,
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirestoreUserScope.creditorsOrdered().snapshots(),
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

          final docs = FirestoreUserScope.sortCreditorsByCreatedAt(
            snapshot.data?.docs ?? const [],
          );

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: 10,
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Chip(label: Text('Totale creditori: ${docs.length}')),
                  ElevatedButton.icon(
                    onPressed: () => _addCreditor(context, docs.length),
                    icon: const Icon(Icons.add),
                    label: const Text('Aggiungi'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: Card(
                  child: docs.isEmpty
                      ? const Center(
                          child: Text(
                            'Nessun creditore presente.\n'
                            'Premi Aggiungi per registrarne uno.',
                            textAlign: TextAlign.center,
                          ),
                        )
                      : ListView.separated(
                          itemCount: docs.length,
                          separatorBuilder: (_, __) =>
                              const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final doc = docs[index];
                            final data = doc.data();
                            final name = (data['name'] ?? '').toString();
                            final notes = (data['notes'] ?? '').toString();
                            final maxAgeRaw = data['maxAge'];
                            final maxAge = maxAgeRaw is int
                                ? maxAgeRaw
                                : int.tryParse(
                                        maxAgeRaw?.toString() ?? '') ??
                                    80;
                            final label = _listLabel(index, name);

                            return ListTile(
                              title: Text(label),
                              subtitle: const Text('Impostazioni creditore'),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () async {
                                final result = await _openCreditorForm(
                                  context,
                                  creditorId: doc.id,
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
