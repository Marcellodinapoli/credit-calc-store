import 'package:flutter/material.dart';

import '../layout/credit_calc_page_host.dart';
import '../nav/credit_calc_nav.dart';

import 'backoffice_pending_plan.dart';
import 'balance_write_off_page.dart';
import 'standard_repayment_plan_page.dart';

class BackofficePendingPlansPage extends StatelessWidget {
  const BackofficePendingPlansPage({super.key});

  String _waitingLabel(BackofficePendingPlan plan) {
    final days = plan.daysWaiting;
    if (days <= 0) return 'In attesa di riscontro · oggi';
    if (days == 1) return 'In attesa di riscontro · 1 giorno';
    return 'In attesa di riscontro · $days giorni';
  }

  String _acceptedLabel(BackofficePendingPlan plan) {
    final via = plan.acceptedVia == BackofficeAcceptedVia.commission
        ? 'tramite incasso in provvigioni'
        : 'manualmente';
    return 'Accettato il ${_formatDate(plan.acceptedAt!)} · $via';
  }

  List<Widget> _planMetaLines(BackofficePendingPlan plan) {
    return [
      Text(
        'Inviato il ${_formatDate(plan.submittedAt)}',
        style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
      ),
      const SizedBox(height: 4),
      if (plan.isAccepted)
        Text(
          _acceptedLabel(plan),
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.green.shade800,
          ),
        )
      else
        Text(
          _waitingLabel(plan),
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.orange.shade900,
          ),
        ),
      if (plan.modifiedAt != null) ...[
        const SizedBox(height: 4),
        Text(
          'Modificato il ${_formatDate(plan.modifiedAt!)}',
          style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
        ),
      ],
    ];
  }

  Future<void> _markAcceptedManual(
    BuildContext context,
    BackofficePendingPlan plan,
  ) async {
    await BackofficePendingPlanService.markAcceptedManual(plan.id);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Piano segnato come accettato.')),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  Future<void> _openPlanEditor(
    BuildContext context,
    BackofficePendingPlan plan, {
    bool autoOpenCommissionExport = false,
  }) async {
    final page = plan.type == BackofficePendingPlanType.repayment
        ? StandardRepaymentPlanPage(
            pendingPlanId: plan.id,
            initialFormData: plan.formData,
            skipInitialUsageGuard: true,
            autoOpenCommissionExport: autoOpenCommissionExport,
            initialCommissionDocIds: plan.commissionDocIds,
          )
        : BalanceWriteOffPage(
            pendingPlanId: plan.id,
            initialFormData: plan.formData,
            skipInitialUsageGuard: true,
            autoOpenCommissionExport: autoOpenCommissionExport,
            initialCommissionDocIds: plan.commissionDocIds,
          );

    await Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(builder: (_) => page),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    BackofficePendingPlan plan,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Elimina piano'),
        content: Text(
          'Eliminare ${plan.type.label} per ${plan.creditorName}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red.shade700,
            ),
            child: const Text('Elimina'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await BackofficePendingPlanService.delete(plan.id);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Piano eliminato')),
    );
  }

  void _showDetails(BuildContext context, BackofficePendingPlan plan) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  plan.type.label,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  plan.creditorName,
                  style: TextStyle(color: Colors.grey.shade700),
                ),
                const SizedBox(height: 4),
                ..._planMetaLines(plan),
                const SizedBox(height: 16),
                Flexible(
                  child: SingleChildScrollView(
                    child: _BackofficeSummaryList(rows: plan.summaryRows),
                  ),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _openPlanEditor(context, plan);
                  },
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Modifica piano'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: plan.hasCommissionExport
                      ? null
                      : () {
                          Navigator.pop(ctx);
                          _openPlanEditor(
                            context,
                            plan,
                            autoOpenCommissionExport: true,
                          );
                        },
                  icon: const Icon(Icons.payments_outlined),
                  label: Text(
                    plan.hasCommissionExport
                        ? 'Incasso già registrato'
                        : 'Aggiungi incasso',
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: plan.isAccepted
                      ? null
                      : () async {
                          Navigator.pop(ctx);
                          await _markAcceptedManual(context, plan);
                        },
                  icon: const Icon(Icons.check_circle_outline),
                  label: Text(
                    plan.isAccepted
                        ? 'Già accettato'
                        : 'Segna come accettato',
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _confirmDelete(context, plan);
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red.shade700,
                    side: BorderSide(color: Colors.red.shade300),
                  ),
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Elimina'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return wrapCreditCalcPage(
      secondary: true,
      pageTitle: 'Riscontro backoffice',
      current: CreditCalcNavItem.develop,
      body: StreamBuilder<List<BackofficePendingPlan>>(
        stream: BackofficePendingPlanService.watchAll(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData &&
              !snapshot.hasError) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline, size: 40, color: Colors.red.shade700),
                    const SizedBox(height: 12),
                    Text(
                      'Impossibile caricare i piani in attesa di riscontro.',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade900,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${snapshot.error}',
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        height: 1.45,
                        fontSize: 13,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          final plans = snapshot.data ?? const [];
          if (plans.isEmpty) {
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Nessun piano in attesa di riscontro.\n'
                  'Dopo aver sviluppato un piano di rientro o un saldo e stralcio, '
                  'usa «Attendi esito» per salvarlo qui.',
                  style: TextStyle(color: Colors.grey.shade700, height: 1.45),
                ),
              ),
            );
          }

          return ListView.separated(
            itemCount: plans.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final plan = plans[index];
              final companyName =
                  (plan.formData['companyName'] ?? '').toString().trim();
              return Card(
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => _showDetails(context, plan),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                plan.type.label,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            if (plan.isAccepted)
                              Container(
                                margin: EdgeInsets.only(
                                  left: plan.hasCommissionExport ? 6 : 0,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade50,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  'Accettato',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.green.shade800,
                                  ),
                                ),
                              ),
                            if (plan.hasCommissionExport)
                              Container(
                                margin: const EdgeInsets.only(left: 6),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade50,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  'Incasso registrato',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.green.shade800,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          plan.creditorName,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        if (companyName.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Ragione sociale: $companyName',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade800,
                            ),
                          ),
                        ],
                        const SizedBox(height: 8),
                        ..._planMetaLines(plan),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _BackofficeSummaryList extends StatelessWidget {
  const _BackofficeSummaryList({required this.rows});

  final List<BackofficeSummaryRow> rows;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final row in rows) ...[
          if (row.note != null && row.note!.isNotEmpty && row.label.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                row.note!,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.4,
                  color: row.note!.startsWith('⚠️')
                      ? Colors.red.shade800
                      : Colors.blue.shade800,
                ),
              ),
            )
          else if (row.label.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 160,
                  child: Text(
                    row.label,
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Expanded(
                  child: row.valueSuffix == null
                      ? Text(
                          row.value,
                          style: TextStyle(
                            fontWeight:
                                row.highlight ? FontWeight.w700 : FontWeight.w600,
                            color: row.highlight
                                ? const Color(0xFF0A66C2)
                                : Colors.black87,
                            fontSize: row.highlight ? 16 : 14,
                          ),
                        )
                      : Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: row.value,
                                style: TextStyle(
                                  fontWeight: row.highlight
                                      ? FontWeight.w700
                                      : FontWeight.w600,
                                  color: row.highlight
                                      ? const Color(0xFF0A66C2)
                                      : Colors.black87,
                                  fontSize: row.highlight ? 16 : 14,
                                ),
                              ),
                              TextSpan(
                                text: ' ${row.valueSuffix}',
                                style: TextStyle(
                                  fontWeight: FontWeight.w400,
                                  color: row.valueSuffixColor == 'green'
                                      ? Colors.green.shade700
                                      : Colors.red.shade700,
                                  fontSize: row.highlight ? 16 : 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                ),
              ],
            ),
          ),
          if (row.note != null && row.note!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                row.note!,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.4,
                  color: row.note!.startsWith('⚠️')
                      ? Colors.red.shade800
                      : Colors.blue.shade800,
                ),
              ),
            ),
          ],
        ],
      ],
    );
  }
}
