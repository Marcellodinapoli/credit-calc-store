import 'package:credit_calc_core/credit_calc_core.dart'
    hide
        CommissionCollectionsHelper,
        CommissionMonthKey,
        CommissionPaymentTypeTotals;
import 'package:flutter/material.dart';

import '../../offline/repository/credit_calc_repository.dart';
import '../../widgets/schedule_field_visit_dialog.dart';
import 'commission_collections_shared.dart';

class CommissionCollectionsPage extends StatefulWidget {
  const CommissionCollectionsPage({super.key});

  @override
  State<CommissionCollectionsPage> createState() =>
      _CommissionCollectionsPageState();
}

class _CommissionCollectionsPageState extends State<CommissionCollectionsPage> {
  /// `null` = Vedi tutti (tutti i mesi con incassi).
  CommissionMonthKey? _selectedMonth = CommissionCollectionsHelper.currentMonth;
  bool _appliedInitialMonth = false;
  String? _selectedCompanyName;
  String? _paymentFilter;
  String? _selectedCreditorName;

  static const _primaryBlue = Color(0xFF0A66C2);

  void _resetFilters() {
    setState(() {
      _selectedMonth = CommissionCollectionsHelper.currentMonth;
      _selectedCompanyName = null;
      _paymentFilter = null;
      _selectedCreditorName = null;
    });
  }

  Widget _summaryStat(String label, String value, {bool highlight = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.black54)),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: highlight ? 22 : 17,
            fontWeight: FontWeight.w700,
            color: highlight ? _primaryBlue : Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _filtersCard({
    required List<CommissionMonthKey> monthOptions,
    required bool hasIncassi,
    required List<String> companyNames,
    required List<String> paymentLabels,
    required List<String> creditorNames,
  }) {
    return Card(
      color: AppCardTheme.surface,
      shape: AppCardTheme.shape,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Filtri',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _resetFilters(),
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Resetta'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<CommissionMonthKey?>(
              value: _selectedMonth,
              decoration: appFormFieldDecoration('Mese'),
              hint: const Text('Nessun incasso registrato'),
              items: [
                if (hasIncassi)
                  const DropdownMenuItem<CommissionMonthKey?>(
                    value: null,
                    child: Text('Vedi tutti'),
                  ),
                ...monthOptions.map(
                  (month) => DropdownMenuItem<CommissionMonthKey?>(
                    value: month,
                    child: Text(
                      CommissionCollectionsHelper.monthLabel(month),
                    ),
                  ),
                ),
              ],
              onChanged: (value) {
                      setState(() {
                        _selectedMonth = value;
                        _selectedCompanyName = null;
                        _paymentFilter = null;
                        _selectedCreditorName = null;
                      });
                    },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String?>(
              value: _selectedCompanyName != null &&
                      companyNames.contains(_selectedCompanyName)
                  ? _selectedCompanyName
                  : null,
              decoration: appFormFieldDecoration('Nominativo (ragione sociale)'),
              isExpanded: true,
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('Tutti i nominativi'),
                ),
                ...companyNames.map(
                  (name) => DropdownMenuItem<String?>(
                    value: name,
                    child: Text(name),
                  ),
                ),
              ],
              onChanged: companyNames.isEmpty
                  ? null
                  : (value) => setState(() => _selectedCompanyName = value),
            ),
            if (companyNames.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  _selectedMonth == null
                      ? 'Nessun nominativo negli incassi.'
                      : 'Nessun nominativo nel mese selezionato.',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String?>(
              value: _paymentFilter,
              decoration: appFormFieldDecoration('Tipologia provvigione'),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('Tutte le tipologie'),
                ),
                ...paymentLabels.map(
                  (label) => DropdownMenuItem<String?>(
                    value: label,
                    child: Text(label),
                  ),
                ),
              ],
              onChanged: (value) => setState(() => _paymentFilter = value),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String?>(
              value: _selectedCreditorName != null &&
                      creditorNames.contains(_selectedCreditorName)
                  ? _selectedCreditorName
                  : null,
              decoration: appFormFieldDecoration('Creditore'),
              isExpanded: true,
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('Tutti i creditori'),
                ),
                ...creditorNames.map(
                  (name) => DropdownMenuItem<String?>(
                    value: name,
                    child: Text(name),
                  ),
                ),
              ],
              onChanged: creditorNames.isEmpty
                  ? null
                  : (value) => setState(() => _selectedCreditorName = value),
            ),
            if (creditorNames.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  _selectedMonth == null
                      ? 'Nessun creditore negli incassi.'
                      : 'Nessun creditore nel mese selezionato.',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ),
          ],
        ),
      ),
    );
  }

  static const _paymentTypeColors = [
    Color(0xFF1565C0),
    Color(0xFF2E7D32),
    Color(0xFF6A1B9A),
    Color(0xFFE65100),
    Color(0xFF00838F),
    Color(0xFFAD1457),
    Color(0xFF4527A0),
  ];

  Color _paymentTypeColor(int index) =>
      _paymentTypeColors[index % _paymentTypeColors.length];

  Widget _paymentTypeLines(List<CommissionPaymentTypeTotals> byType) {
    if (byType.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < byType.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: RichText(
                text: TextSpan(
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.45,
                    color: Colors.black87,
                  ),
                  children: [
                    TextSpan(
                      text: '${byType[i].label}: ',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: _paymentTypeColor(i),
                      ),
                    ),
                    TextSpan(
                      text:
                          'Incassato ${CommissionCollectionsHelper.formatEuro(byType[i].collected)} - ',
                    ),
                    TextSpan(
                      text:
                          'Provvigioni ${CommissionCollectionsHelper.formatEuro(byType[i].commission)}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _summaryCard({
    required CommissionMonthKey? month,
    required List<CreditCalcRecord> filtered,
    required double totalCollected,
    required double totalCommission,
    required List<CommissionPaymentTypeTotals> byPaymentType,
  }) {
    return Card(
      shape: AppCardTheme.shape,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              month == null
                  ? 'Tutti i mesi'
                  : CommissionCollectionsHelper.monthLabel(month),
              style: TextStyle(
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _summaryStat(
                    'Incassato',
                    CommissionCollectionsHelper.formatEuro(totalCollected),
                  ),
                ),
                Expanded(
                  child: _summaryStat(
                    'Provvigioni',
                    CommissionCollectionsHelper.formatEuro(totalCommission),
                    highlight: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${filtered.length} '
              '${filtered.length == 1 ? 'pratica' : 'pratiche'} '
              'dai filtri applicati',
              style: const TextStyle(
                color: Colors.black54,
                fontSize: 12,
              ),
            ),
            _paymentTypeLines(byPaymentType),
          ],
        ),
      ),
    );
  }

  Future<void> _editEntry(String docId) async {
    final updated = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => CommissionEntryPage(entryId: docId),
      ),
    );
    if (updated == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Incasso aggiornato.')),
      );
    }
  }

  Future<void> _deleteEntry(String docId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Elimina incasso'),
        content: const Text(
          'Confermi l\'eliminazione definitiva di questa pratica?',
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

    if (confirm != true || !mounted) return;

    try {
      await CreditCalcRepository.instance.deleteCalculation(docId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Incasso eliminato.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Errore durante l\'eliminazione.')),
      );
    }
  }

  Widget _entryTile(CreditCalcRecord doc) {
    final data = doc.data;
    final docId = doc.id;
    final date = CommissionCollectionsHelper.entryDate(data);
    final company = CommissionCollectionsHelper.companyName(data);
    final creditor = (data['creditorName'] ?? '—').toString().trim();
    final payment = CommissionCollectionsHelper.paymentLabel(data);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      company.isEmpty ? '—' : company,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text('Creditore: ${creditor.isEmpty ? '—' : creditor}'),
                    Text('Tipologia: ${payment.isEmpty ? '—' : payment}'),
                    if (date != null)
                      Text(
                        'Data incasso: ${CommissionCollectionsHelper.formatDate(date)}',
                      ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    CommissionCollectionsHelper.formatEuro(
                      CommissionCollectionsHelper.numField(
                        data,
                        'amountCollected',
                      ),
                    ),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    'Provv. ${CommissionCollectionsHelper.formatEuro(CommissionCollectionsHelper.entryCommissionTotal(data))}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.green.shade700,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: () => showScheduleFieldVisitDialog(
                  context,
                  calculation: data,
                  calculationId: docId,
                ),
                icon: const Icon(Icons.event_available_outlined, size: 18),
                label: const Text('Programma visita'),
              ),
              TextButton.icon(
                onPressed: () => _editEntry(docId),
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('Modifica'),
              ),
              TextButton.icon(
                onPressed: () => _deleteEntry(docId),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.red.shade700,
                ),
                icon: const Icon(Icons.delete_outline, size: 18),
                label: const Text('Elimina'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return wrapCreditCalcPage(
      secondary: true,
      pageTitle: 'Elenco incassi',
      current: CreditCalcNavItem.commissions,
      body: StreamBuilder<List<CreditCalcRecord>>(
        stream: CreditCalcRepository.instance.watchCalculationRecords(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Impossibile caricare gli incassi.\n${snapshot.error}',
                textAlign: TextAlign.center,
              ),
            );
          }

          final allDocs = CommissionCollectionsHelper.commissionRecords(
            snapshot.data,
          );
          final monthsWithIncassi =
              CommissionCollectionsHelper.monthsForFilterRecords(allDocs);
          final monthOptions =
              CommissionCollectionsHelper.monthsForFilterDropdownRecords(allDocs);

          if (!_appliedInitialMonth) {
            _appliedInitialMonth = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              setState(
                () => _selectedMonth = CommissionCollectionsHelper.currentMonth,
              );
            });
          } else if (_selectedMonth != null &&
              !monthOptions.contains(_selectedMonth)) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              setState(
                () => _selectedMonth = CommissionCollectionsHelper.currentMonth,
              );
            });
          }

          final paymentLabels =
              CommissionCollectionsHelper.paymentLabelsInMonthRecords(
            allDocs,
            _selectedMonth,
          );
          final companyNames =
              CommissionCollectionsHelper.companyNamesInMonthRecords(
            allDocs,
            _selectedMonth,
          );
          final creditorNames =
              CommissionCollectionsHelper.creditorNamesInMonthRecords(
            allDocs,
            _selectedMonth,
          );

          if (_paymentFilter != null &&
              !paymentLabels.contains(_paymentFilter)) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) setState(() => _paymentFilter = null);
            });
          }

          if (_selectedCompanyName != null &&
              !companyNames.contains(_selectedCompanyName)) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) setState(() => _selectedCompanyName = null);
            });
          }

          if (_selectedCreditorName != null &&
              !creditorNames.contains(_selectedCreditorName)) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) setState(() => _selectedCreditorName = null);
            });
          }

          final filtered = CommissionCollectionsHelper.filterRecords(
            allDocs,
            month: _selectedMonth,
            selectedCompanyName: _selectedCompanyName,
            paymentLabelFilter: _paymentFilter,
            selectedCreditorName: _selectedCreditorName,
          );

          final totalCollected =
              CommissionCollectionsHelper.totalCollectedRecords(filtered);
          final totalCommission =
              CommissionCollectionsHelper.totalCommissionRecords(filtered);
          final byPaymentType =
              CommissionCollectionsHelper.totalsByPaymentTypeRecords(filtered);

          return ListView(
            children: [
              _filtersCard(
                monthOptions: monthOptions,
                hasIncassi: monthsWithIncassi.isNotEmpty,
                companyNames: companyNames,
                paymentLabels: paymentLabels,
                creditorNames: creditorNames,
              ),
              const SizedBox(height: 12),
              _summaryCard(
                month: _selectedMonth,
                filtered: filtered,
                totalCollected: totalCollected,
                totalCommission: totalCommission,
                byPaymentType: byPaymentType,
              ),
              const SizedBox(height: 12),
              Card(
                shape: AppCardTheme.shape,
                clipBehavior: Clip.antiAlias,
                child: filtered.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'Nessuna pratica corrisponde ai filtri selezionati.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.black54),
                        ),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (_, index) => _entryTile(filtered[index]),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
