import 'package:flutter/material.dart';

import '../layout/credit_calc_page_host.dart';
import '../nav/credit_calc_nav.dart';

import 'backoffice_pending_plan.dart';
import 'backoffice_pending_plan_host_config.dart';
import 'balance_write_off_page.dart';
import 'commission_collections_shared.dart';
import 'commission_entries_data_access.dart';
import 'standard_repayment_plan_page.dart';

class BackofficePendingPlansPage extends StatefulWidget {
  const BackofficePendingPlansPage({super.key});

  @override
  State<BackofficePendingPlansPage> createState() =>
      _BackofficePendingPlansPageState();
}

class _BackofficePendingPlansPageState extends State<BackofficePendingPlansPage> {
  DateTime? _selectedDay;
  bool _useCurrentMonth = false;
  bool _calendarVisible = false;
  late DateTime _calendarFocusDay;
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _calendarFocusDay = DateTime(now.year, now.month, now.day);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  DateTime _calendarDay(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  bool _isCurrentMonth(DateTime value) {
    final now = DateTime.now();
    return value.year == now.year && value.month == now.month;
  }

  Set<DateTime> _planDays(List<BackofficePendingPlan> plans) =>
      plans.map((plan) => _calendarDay(plan.submittedAt)).toSet();

  List<BackofficePendingPlan> _filterPlans(
    List<BackofficePendingPlan> plans,
    List<CommissionEntryRecord> entries,
  ) {
    List<BackofficePendingPlan> result;
    if (_selectedDay != null) {
      result = plans
          .where((plan) => _calendarDay(plan.submittedAt) == _selectedDay)
          .toList(growable: false);
    } else if (_useCurrentMonth) {
      result = plans
          .where((plan) => _isCurrentMonth(plan.submittedAt))
          .toList(growable: false);
    } else {
      result = List<BackofficePendingPlan>.from(plans);
    }

    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) return result;

    final matchingEntryIds = <String>{
      for (final entry in entries)
        if (_entryNameMatches(entry, query)) entry.id,
    };

    return result.where((plan) {
      final planCompany = (plan.companyName ?? '').toLowerCase();
      if (planCompany.contains(query)) return true;
      if (plan.creditorName.toLowerCase().contains(query)) return true;
      if (plan.commissionDocIds.any(matchingEntryIds.contains)) return true;

      if (planCompany.isEmpty || plan.creditorId.isEmpty) return false;
      for (final entry in entries) {
        if (!matchingEntryIds.contains(entry.id)) continue;
        final entryCreditorId = (entry.data['creditorId'] ?? '').toString();
        final entryCompany =
            CommissionCollectionsHelper.companyName(entry.data).toLowerCase();
        if (entryCreditorId == plan.creditorId && entryCompany == planCompany) {
          return true;
        }
      }
      return false;
    }).toList(growable: false);
  }

  bool _entryNameMatches(CommissionEntryRecord entry, String query) {
    final data = entry.data;
    final company = CommissionCollectionsHelper.companyName(data).toLowerCase();
    final creditor = CommissionCollectionsHelper.creditorName(data).toLowerCase();
    return company.contains(query) || creditor.contains(query);
  }

  String _filterLabel() {
    if (_selectedDay != null) {
      return 'Piani inseriti il ${_formatDate(_selectedDay!)}';
    }
    if (_useCurrentMonth) {
      final now = DateTime.now();
      final month = now.month.toString().padLeft(2, '0');
      return 'Piani inseriti nel mese in corso ($month/${now.year})';
    }
    return 'Tutti i piani in attesa di riscontro';
  }

  String _emptyMessage(List<BackofficePendingPlan> allPlans) {
    if (allPlans.isEmpty) {
      return 'Nessun piano in attesa di riscontro.\n'
          'Dopo aver sviluppato un piano di rientro o un saldo e stralcio, '
          'usa «Attendi esito» per salvarlo qui.';
    }
    if (_searchQuery.trim().isNotEmpty) {
      return 'Nessun piano trovato per «${_searchQuery.trim()}» '
          'nel periodo selezionato.\n'
          'Verifica il nominativo registrato negli incassi o cambia mese/data.';
    }
    if (_selectedDay != null) {
      return 'Nessun piano inserito il ${_formatDate(_selectedDay!)}.';
    }
    if (_useCurrentMonth) {
      return 'Nessun piano inserito nel mese in corso.\n'
          'Apri il calendario per scegliere un altro giorno.';
    }
    return 'Nessun piano corrisponde ai filtri selezionati.\n'
        'Usa «Mese in corso» o «Scegli data» per restringere l\'elenco.';
  }

  Widget _buildSearchField() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: TextField(
          controller: _searchCtrl,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            labelText: 'Cerca nominativo incasso',
            hintText: 'Ragione sociale o creditore registrato in provvigioni',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _searchQuery.trim().isEmpty
                ? null
                : IconButton(
                    tooltip: 'Cancella ricerca',
                    onPressed: () {
                      _searchCtrl.clear();
                      setState(() => _searchQuery = '');
                    },
                    icon: const Icon(Icons.clear),
                  ),
            border: const OutlineInputBorder(),
            isDense: true,
          ),
          onChanged: (value) => setState(() => _searchQuery = value),
        ),
      ),
    );
  }

  Widget _buildHeader(Set<DateTime> planDays) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSearchField(),
        const SizedBox(height: 12),
        _buildCalendar(planDays),
      ],
    );
  }

  DateTime _safeCalendarInitialDate(Set<DateTime> planDays) {
    if (planDays.isEmpty) {
      return _calendarDay(DateTime.now());
    }

    final today = _calendarDay(DateTime.now());
    if (_selectedDay != null) {
      final selected = _calendarDay(_selectedDay!);
      if (planDays.contains(selected)) return selected;
    }

    final focus = _calendarDay(_calendarFocusDay);
    if (planDays.contains(focus)) return focus;
    if (planDays.contains(today)) return today;

    final sorted = planDays.toList()..sort();
    return sorted.last;
  }

  Widget _buildCalendar(Set<DateTime> planDays) {
    if (planDays.isEmpty) return const SizedBox.shrink();

    final sortedDays = planDays.toList()..sort();
    final firstDate = sortedDays.first;
    final lastDate = sortedDays.last;
    final today = _calendarDay(DateTime.now());
    final lastSelectable = lastDate.isAfter(today) ? lastDate : today;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 12, 8, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _filterLabel(),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilterChip(
                  label: const Text('Mese in corso'),
                  selected: _useCurrentMonth && _selectedDay == null,
                  onSelected: (selected) {
                    setState(() {
                      _useCurrentMonth = selected;
                      _selectedDay = null;
                      _calendarVisible = false;
                      if (selected) {
                        final now = DateTime.now();
                        _calendarFocusDay =
                            DateTime(now.year, now.month, now.day);
                      }
                    });
                  },
                ),
                ActionChip(
                  avatar: Icon(
                    _calendarVisible
                        ? Icons.calendar_month
                        : Icons.calendar_month_outlined,
                    size: 18,
                  ),
                  label: Text(
                    _calendarVisible ? 'Chiudi calendario' : 'Scegli data',
                  ),
                  onPressed: () {
                    setState(() {
                      _calendarVisible = !_calendarVisible;
                      if (_calendarVisible) {
                        _useCurrentMonth = false;
                        _calendarFocusDay = _safeCalendarInitialDate(planDays);
                      }
                    });
                  },
                ),
                if (_selectedDay != null)
                  InputChip(
                    label: Text(_formatDate(_selectedDay!)),
                    onDeleted: () {
                      setState(() {
                        _selectedDay = null;
                        _calendarVisible = false;
                        _calendarFocusDay = _safeCalendarInitialDate(planDays);
                      });
                    },
                  ),
              ],
            ),
            if (_calendarVisible) ...[
              const SizedBox(height: 4),
              CalendarDatePicker(
                key: ValueKey(
                  '${_calendarFocusDay.year}-${_calendarFocusDay.month}-'
                  '${_selectedDay?.millisecondsSinceEpoch ?? 'month'}-'
                  '${planDays.length}',
                ),
                initialDate: _safeCalendarInitialDate(planDays),
                firstDate: firstDate,
                lastDate: lastSelectable,
                currentDate: today,
                onDateChanged: (date) {
                  final day = _calendarDay(date);
                  if (!planDays.contains(day)) return;
                  setState(() {
                    _selectedDay = day;
                    _useCurrentMonth = false;
                    _calendarFocusDay = day;
                  });
                },
                selectableDayPredicate: (date) =>
                    planDays.contains(_calendarDay(date)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _waitingLabel(BackofficePendingPlan plan) {
    final days = plan.daysWaiting;
    if (days <= 0) return 'In attesa di riscontro · oggi';
    if (days == 1) return 'In attesa di riscontro · 1 giorno';
    return 'In attesa di riscontro · $days giorni';
  }

  String _acceptedLabel(
    BackofficePendingPlan plan, {
    bool includeVia = true,
  }) {
    final date = 'Accettato il ${_formatDate(plan.acceptedAt!)}';
    if (!includeVia) return date;
    final via = plan.acceptedVia == BackofficeAcceptedVia.commission
        ? 'tramite incasso in provvigioni'
        : 'manualmente';
    return '$date · $via';
  }

  List<Widget> _planMetaLines(
    BackofficePendingPlan plan, {
    bool includeAcceptedVia = true,
    bool showIncassoInserito = false,
  }) {
    return [
      Text(
        'Inviato il ${_formatDate(plan.submittedAt)}',
        style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
      ),
      const SizedBox(height: 4),
      if (plan.isAccepted)
        Text(
          _acceptedLabel(plan, includeVia: includeAcceptedVia),
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
      if (showIncassoInserito &&
          plan.isAccepted &&
          plan.hasCommissionExport) ...[
        const SizedBox(height: 4),
        Text(
          'Incasso inserito',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.green.shade800,
          ),
        ),
      ],
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
    await BackofficePendingPlanHostConfig.ensureDataReady?.call();
    if (!context.mounted) return;

    final request = BackofficePlanEditorRequest(
      pendingPlanId: plan.id,
      initialFormData: plan.formData,
      skipInitialUsageGuard: true,
      autoOpenCommissionExport: autoOpenCommissionExport,
      initialCommissionDocIds: plan.commissionDocIds,
      initialCompanyName: plan.companyName,
    );

    final page = plan.type == BackofficePendingPlanType.repayment
        ? BackofficePendingPlanHostConfig.buildRepaymentPlanPage?.call(request) ??
            StandardRepaymentPlanPage(
              pendingPlanId: request.pendingPlanId,
              initialFormData: request.initialFormData,
              skipInitialUsageGuard: request.skipInitialUsageGuard,
              autoOpenCommissionExport: request.autoOpenCommissionExport,
              initialCommissionDocIds: request.initialCommissionDocIds,
              initialCompanyName: request.initialCompanyName,
            )
        : BackofficePendingPlanHostConfig.buildBalanceWriteOffPage?.call(request) ??
            BalanceWriteOffPage(
              pendingPlanId: request.pendingPlanId,
              initialFormData: request.initialFormData,
              skipInitialUsageGuard: request.skipInitialUsageGuard,
              autoOpenCommissionExport: request.autoOpenCommissionExport,
              initialCommissionDocIds: request.initialCommissionDocIds,
              initialCompanyName: request.initialCompanyName,
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
        builder: (context, plansSnap) {
          return StreamBuilder<List<CommissionEntryRecord>>(
            stream: CommissionEntriesDataAccess.instance.watchCommissionEntries(),
            builder: (context, entriesSnap) {
              if (plansSnap.connectionState == ConnectionState.waiting ||
                  entriesSnap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final allPlans = plansSnap.data ?? const [];
              final entries = entriesSnap.data ?? const [];
              final planDays = _planDays(allPlans);
              final plans = _filterPlans(allPlans, entries);

              // Search/header fuori dalla ListView filtrata: altrimenti a ogni
              // lettera cambia itemCount e il TextField perde il focus.
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHeader(planDays),
                  const SizedBox(height: 12),
                  Expanded(
                    child: plans.isEmpty
                        ? ListView(
                            children: [
                              Card(
                                child: Padding(
                                  padding: const EdgeInsets.all(24),
                                  child: Text(
                                    _emptyMessage(allPlans),
                                    style: TextStyle(
                                      color: Colors.grey.shade700,
                                      height: 1.45,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          )
                        : ListView.separated(
                            itemCount: plans.length,
                            separatorBuilder: (context, index) =>
                                const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final plan = plans[index];
                              return Card(
                                clipBehavior: Clip.antiAlias,
                                child: InkWell(
                                  onTap: () => _showDetails(context, plan),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
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
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 8,
                                                  vertical: 4,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: Colors.green.shade50,
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          999),
                                                ),
                                                child: Text(
                                                  'Accettato',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w600,
                                                    color:
                                                        Colors.green.shade800,
                                                  ),
                                                ),
                                              )
                                            else if (plan.hasCommissionExport)
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 8,
                                                  vertical: 4,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: Colors.green.shade50,
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          999),
                                                ),
                                                child: Text(
                                                  'Incasso registrato',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w600,
                                                    color:
                                                        Colors.green.shade800,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        if (plan.companyName?.isNotEmpty ==
                                            true) ...[
                                          Text(
                                            plan.companyName!,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 15,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                        ],
                                        Text(
                                          plan.creditorName,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        ..._planMetaLines(
                                          plan,
                                          includeAcceptedVia: false,
                                          showIncassoInserito: true,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
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
