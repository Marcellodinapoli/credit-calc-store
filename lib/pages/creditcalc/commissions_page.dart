import 'package:credit_calc_core/credit_calc_core.dart'
    hide
        CommissionCollectionsHelper,
        CommissionCollectionsPage,
        CommissionMonthKey;
import 'package:flutter/material.dart';

import '../../offline/repository/credit_calc_repository.dart';
import '../../services/read_state_service.dart';
import 'commission_collections_page.dart';
import 'commission_collections_shared.dart';
import 'commission_statistics_page.dart';

class CommissionsPage extends StatefulWidget {
  const CommissionsPage({super.key});

  @override
  State<CommissionsPage> createState() => _CommissionsPageState();
}

class _CommissionsPageState extends State<CommissionsPage> {
  bool _showCollectionsPreview = true;
  bool _previewPreferenceLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadPreviewPreference();
  }

  @override
  void activate() {
    super.activate();
    _loadPreviewPreference();
  }

  Future<void> _loadPreviewPreference() async {
    final visible = await ReadStateService.getCommissionsPreviewVisible();
    if (!mounted) return;
    setState(() {
      _showCollectionsPreview = visible;
      _previewPreferenceLoaded = true;
    });
  }

  Future<void> _toggleCollectionsPreview() async {
    final next = !_showCollectionsPreview;
    setState(() => _showCollectionsPreview = next);
    await ReadStateService.setCommissionsPreviewVisible(next);
  }

  Widget _compactPreview(List<CreditCalcRecord> allDocs) {
    final currentMonth = CommissionMonthKey.fromDate(DateTime.now());
    final monthDocs = CommissionCollectionsHelper.filterRecords(
      allDocs,
      month: currentMonth,
    );
    final totalCommission =
        CommissionCollectionsHelper.totalCommissionRecords(monthDocs);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          constraints: const BoxConstraints(minWidth: 180),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: AppCardTheme.surface,
            borderRadius: BorderRadius.circular(AppCardTheme.radius),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Provvigioni',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                CommissionCollectionsHelper.formatEuro(totalCommission),
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0A66C2),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                monthDocs.isEmpty
                    ? 'Nessun incasso nel mese corrente'
                    : '${CommissionCollectionsHelper.monthLabel(currentMonth)} · '
                        '${monthDocs.length} '
                        '${monthDocs.length == 1 ? 'pratica' : 'pratiche'}',
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _collectionsCard() {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            leading: const Icon(Icons.receipt_long_outlined),
            title: const Text('Incassi effettuati'),
            subtitle: const Text(
              'Anteprima provvigioni del mese corrente ed elenco completo.',
            ),
            trailing: IconButton(
              tooltip: _showCollectionsPreview
                  ? 'Nascondi anteprima provvigioni'
                  : 'Mostra anteprima provvigioni',
              onPressed:
                  _previewPreferenceLoaded ? _toggleCollectionsPreview : null,
              icon: Icon(
                _showCollectionsPreview
                    ? Icons.visibility
                    : Icons.visibility_off,
              ),
            ),
          ),
          StreamBuilder<List<CreditCalcRecord>>(
            stream: CreditCalcRepository.instance.watchCalculationRecords(),
            builder: (context, snapshot) {
              if (!_previewPreferenceLoaded) {
                return const SizedBox.shrink();
              }
              if (_showCollectionsPreview) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: LinearProgressIndicator(minHeight: 2),
                  );
                }

                if (snapshot.hasError) {
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Text(
                      'Impossibile caricare l\'anteprima.',
                      style: TextStyle(color: Colors.red.shade700),
                    ),
                  );
                }

                return _compactPreview(
                  CommissionCollectionsHelper.commissionRecords(snapshot.data),
                );
              }

              return const SizedBox.shrink();
            },
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: OutlinedButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const CommissionCollectionsPage(),
                  ),
                );
              },
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                alignment: Alignment.center,
              ),
              icon: const Icon(Icons.list_alt_outlined),
              label: const Text('Vedi elenco pratiche'),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return wrapCreditCalcPage(
      pageTitle: 'Provvigioni',
      current: CreditCalcNavItem.commissions,
      body: ListView(
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.tune),
              title: const Text('Imposta provvigioni'),
              subtitle: const Text(
                'Configura aliquote, soglie e regole di calcolo delle provvigioni.',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => CommissionCreditorPicker.openSettings(context),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.insights_outlined),
              title: const Text('Statistiche e confronti'),
              subtitle: const Text(
                'Andamento mensile e annuale di incassi e provvigioni.',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const CommissionStatisticsPage(),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.edit_note),
              title: const Text('Inserisci provvigioni'),
              subtitle: const Text(
                'Registra un nuovo incasso e le relative provvigioni.',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
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
              },
            ),
          ),
          const SizedBox(height: 12),
          _collectionsCard(),
        ],
      ),
    );
  }
}
