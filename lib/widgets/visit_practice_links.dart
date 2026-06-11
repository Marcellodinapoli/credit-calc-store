import 'package:flutter/material.dart';

import '../models/field_visit.dart';
import '../offline/repository/credit_calc_repository.dart';
import '../pages/creditcalc/commission_entry_page.dart';
import '../pages/creditcalc/creditor_detail_page.dart';

class VisitPracticeLinks extends StatelessWidget {
  const VisitPracticeLinks({super.key, required this.visit});

  final FieldVisit visit;

  Future<void> _openCreditor(BuildContext context) async {
    final id = visit.creditorId?.trim();
    if (id == null || id.isEmpty) return;

    final doc = await CreditCalcRepository.instance.getCreditor(id);
    if (!context.mounted) return;

    final data = doc?.data ?? {};
    await showDialog<Object?>(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (ctx) => Dialog.fullscreen(
        child: CreditorDetailPage(
          creditorId: id,
          name: (data['displayLabel'] ?? data['name'] ?? visit.creditorName ?? 'Creditore')
              .toString(),
          maxAge: (data['maxAge'] as num?)?.toInt() ?? 80,
        ),
      ),
    );
  }

  void _openCommission(BuildContext context) {
    final id = visit.calculationId?.trim();
    if (id == null || id.isEmpty) return;

    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
        builder: (_) => CommissionEntryPage(entryId: id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasCreditor =
        visit.creditorId != null && visit.creditorId!.trim().isNotEmpty;
    final hasIncasso =
        visit.calculationId != null && visit.calculationId!.trim().isNotEmpty;

    if (!hasCreditor && !hasIncasso) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Wrap(
        spacing: 4,
        children: [
          if (hasCreditor)
            TextButton.icon(
              onPressed: () => _openCreditor(context),
              icon: const Icon(Icons.account_balance, size: 16),
              label: const Text('Creditore'),
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
              ),
            ),
          if (hasIncasso)
            TextButton.icon(
              onPressed: () => _openCommission(context),
              icon: const Icon(Icons.receipt_long, size: 16),
              label: const Text('Incasso'),
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
              ),
            ),
        ],
      ),
    );
  }
}
