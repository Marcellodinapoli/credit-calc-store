import 'package:credit_calc_core/credit_calc_core.dart';
import 'package:flutter/material.dart';

import '../../core/dimensions.dart';
import '../../models/field_reminder.dart';
import '../../models/field_visit.dart';
import '../../services/creditor_visit_address_service.dart';
import '../../services/field_reminder_service.dart';
import '../../services/field_visit_service.dart';
import '../../services/installment_monitor_service.dart';
import '../../widgets/address_field_with_scan.dart';

class InstallmentMonitorPage extends StatefulWidget {
  const InstallmentMonitorPage({super.key});

  @override
  State<InstallmentMonitorPage> createState() => _InstallmentMonitorPageState();
}

class _InstallmentMonitorPageState extends State<InstallmentMonitorPage> {
  List<InstallmentMonitorConfig> _configs = const [];
  bool _loadingConfigs = true;

  @override
  void initState() {
    super.initState();
    _reloadConfigs();
  }

  Future<void> _reloadConfigs() async {
    final configs = await InstallmentMonitorService.loadConfigs();
    if (!mounted) return;
    setState(() {
      _configs = configs;
      _loadingConfigs = false;
    });
  }

  Future<void> _pickMonitorPlan(InstallmentMonitorPractice practice) async {
    final plan = await showDialog<InstallmentMonitorPlan>(
      context: context,
      builder: (ctx) => _InstallmentMonitorPlanDialog(practice: practice),
    );

    if (plan == null || !mounted) return;

    try {
      await InstallmentMonitorService.activate(practice: practice, plan: plan);
      await _reloadConfigs();
      if (!mounted) return;
      final modeLabel = plan.followUpMode.shortLabel.toLowerCase();
      final destination = plan.followUpMode ==
              InstallmentMonitorFollowUpMode.telefonico
          ? 'Promemoria'
          : 'Appuntamenti';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Monitoraggio $modeLabel attivo per ${plan.ratesToMonitor} '
            '${plan.ratesToMonitor == 1 ? 'rata' : 'rate'}. '
            'Inserito in $destination.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore: $e')),
      );
    }
  }

  Future<void> _stopMonitor(InstallmentMonitorConfig config) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Elimina monitoraggio'),
        content: Text(
          'Rimuovere promemoria, appuntamenti e notifiche per '
          '${config.companyName}? Tutte le date registrate verranno eliminate.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Rimuovi'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await InstallmentMonitorService.deactivate(config.id);
    await _reloadConfigs();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Monitoraggio eliminato per ${config.companyName}.')),
    );
  }

  InstallmentMonitorPractice? _practiceForConfig(
    InstallmentMonitorConfig config,
    List<InstallmentMonitorPractice> practices,
  ) {
    for (final practice in practices) {
      if (practice.creditorId == config.creditorId &&
          practice.companyName == config.companyName) {
        return practice;
      }
    }
    return null;
  }

  Future<InstallmentMonitorPlan> _planFromConfig(
    InstallmentMonitorConfig config,
  ) async {
    var address = '';
    if (config.followUpMode == InstallmentMonitorFollowUpMode.domiciliare &&
        config.visitIds.isNotEmpty) {
      final visits = await FieldVisitService.fetchAllForUser();
      for (final visit in visits) {
        if (config.visitIds.contains(visit.id)) {
          address = visit.address;
          break;
        }
      }
    }
    return InstallmentMonitorPlan(
      ratesToMonitor: config.ratesMonitored,
      followUpMode: config.followUpMode,
      visitAddress: address,
    );
  }

  Future<void> _editMonitor(
    InstallmentMonitorConfig config,
    List<InstallmentMonitorPractice> practices,
  ) async {
    final practice = _practiceForConfig(config, practices);
    if (practice == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Pratica non trovata. Verifica che gli incassi siano ancora in provvigioni.',
          ),
        ),
      );
      return;
    }

    final initialPlan = await _planFromConfig(config);
    if (!mounted) return;

    final plan = await showDialog<InstallmentMonitorPlan>(
      context: context,
      builder: (ctx) => _InstallmentMonitorPlanDialog(
        practice: practice,
        initialPlan: initialPlan,
      ),
    );

    if (plan == null || !mounted) return;

    try {
      await InstallmentMonitorService.update(
        config: config,
        practice: practice,
        plan: plan,
      );
      await _reloadConfigs();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Monitoraggio aggiornato: ${plan.ratesToMonitor} '
            '${plan.ratesToMonitor == 1 ? 'rata' : 'rate'} · '
            '${plan.followUpMode.shortLabel}.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore: $e')),
      );
    }
  }

  String _formatInstallmentLine(CommissionEntryRecord entry, int index) {
    final date = CommissionCollectionsHelper.entryDate(entry.data);
    final amount = CommissionCollectionsHelper.numField(
      entry.data,
      'amountCollected',
    );
    final dateLabel =
        date == null ? '—' : CommissionCollectionsHelper.formatDate(date);
    return 'Rata ${index + 1}: $dateLabel · ${CommissionCollectionsHelper.formatEuro(amount)}';
  }

  @override
  Widget build(BuildContext context) {
    final body = StreamBuilder<List<CommissionEntryRecord>>(
        stream: CommissionEntriesDataAccess.instance.watchCommissionEntries(),
        builder: (context, entriesSnap) {
          if (!entriesSnap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final practicesFuture =
              InstallmentMonitorService.practicesFromEntriesAsync(
            entriesSnap.data!,
          );

          return FutureBuilder<List<InstallmentMonitorPractice>>(
            future: practicesFuture,
            builder: (context, practicesSnap) {
              if (!practicesSnap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final practices = practicesSnap.data!;

          return StreamBuilder<List<FieldReminder>>(
            stream: FieldReminderService.watchUpcoming(),
            builder: (context, remindersSnap) {
              return StreamBuilder<List<FieldVisit>>(
                stream: FieldVisitService.watchAllForUser(),
                builder: (context, visitsSnap) {
                  final badgeCount =
                      InstallmentMonitorService.upcomingAlertCount(
                    reminders: remindersSnap.data ?? const [],
                    visits: visitsSnap.data ?? const [],
                  );

              return ListView(
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                padding: Dimensions.scrollPadding(context),
                    children: [
                      if (badgeCount > 0)
                        Card(
                          color: ProjectColors.calc.withValues(alpha: 0.08),
                          child: ListTile(
                            leading: Badge(
                              isLabelVisible: badgeCount > 0,
                              label: Text('$badgeCount'),
                              child: const Icon(Icons.notifications_active),
                            ),
                            title: const Text('Scadenze in arrivo'),
                            subtitle: Text(
                              '$badgeCount '
                              '${badgeCount == 1 ? 'scadenza' : 'scadenze'} '
                              'nei prossimi 7 giorni',
                            ),
                          ),
                        ),
                      const SizedBox(height: 8),
                      const Text(
                        'Seleziona una pratica dalle provvigioni, indica quante rate '
                        'monitorare e scegli se ricevere solo una notifica per '
                        'sollecito telefonico o inserire visite domiciliari in '
                        'Itinerario alla scadenza PDR.',
                        style: TextStyle(color: Colors.black54, height: 1.45),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Pratiche in provvigioni',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 8),
                      if (practices.isEmpty)
                        const Card(
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: Text(
                              'Nessuna pratica con incassi in provvigioni. '
                              'Esporta un piano di rientro o saldo e stralcio '
                              'verso Provvigioni per abilitare il monitoraggio.',
                            ),
                          ),
                        )
                      else
                        Card(
                          child: Column(
                            children: [
                              for (var i = 0; i < practices.length; i++) ...[
                                if (i > 0) const Divider(height: 1),
                                _PracticeTile(
                                  practice: practices[i],
                                  config:
                                      InstallmentMonitorService.configForPractice(
                                    practices[i],
                                    _configs,
                                  ),
                                  onActivate: () =>
                                      _pickMonitorPlan(practices[i]),
                                  installmentLabel: _formatInstallmentLine,
                                ),
                              ],
                            ],
                          ),
                        ),
                      const SizedBox(height: 24),
                      Text(
                        'Monitoraggi attivi',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 8),
                      if (_loadingConfigs)
                        const Center(child: CircularProgressIndicator())
                      else if (_configs.isEmpty)
                        const Card(
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: Text('Nessun monitoraggio attivo.'),
                          ),
                        )
                      else
                        Card(
                          child: Column(
                            children: [
                              for (var i = 0; i < _configs.length; i++) ...[
                                if (i > 0) const Divider(height: 1),
                                ListTile(
                                  title: Text(_configs[i].companyName),
                                  subtitle: Text(
                                    '${_configs[i].creditorName}\n'
                                    '${_configs[i].ratesMonitored} rate · '
                                    '${_configs[i].followUpMode.label}',
                                  ),
                                  isThreeLine: true,
                                  trailing: PopupMenuButton<String>(
                                    tooltip: 'Azioni monitoraggio',
                                    onSelected: (action) {
                                      if (action == 'edit') {
                                        _editMonitor(_configs[i], practices);
                                      } else if (action == 'delete') {
                                        _stopMonitor(_configs[i]);
                                      }
                                    },
                                    itemBuilder: (_) => const [
                                      PopupMenuItem(
                                        value: 'edit',
                                        child: Text('Modifica'),
                                      ),
                                      PopupMenuItem(
                                        value: 'delete',
                                        child: Text('Elimina'),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                    ],
                  );
                },
              );
            },
          );
            },
          );
        },
      );

    return wrapCreditCalcPage(
      secondary: true,
      pageTitle: 'Monitora rateizzo',
      current: CreditCalcNavItem.develop,
      body: body,
    );
  }
}

class _PracticeTile extends StatelessWidget {
  const _PracticeTile({
    required this.practice,
    required this.config,
    required this.onActivate,
    required this.installmentLabel,
  });

  final InstallmentMonitorPractice practice;
  final InstallmentMonitorConfig? config;
  final VoidCallback onActivate;
  final String Function(CommissionEntryRecord entry, int index) installmentLabel;

  @override
  Widget build(BuildContext context) {
    final preview = practice.installments.take(3).toList();
    final subtitle = StringBuffer()
      ..writeln(practice.creditorName)
      ..writeln(
        practice.pdrInstallments.isNotEmpty
            ? '${practice.totalRates} rate del rateizzo PDR'
            : '${practice.totalRates} rate in provvigioni',
      );
    for (var i = 0; i < preview.length; i++) {
      subtitle.writeln(installmentLabel(preview[i], i));
    }
    if (practice.totalRates > 3) {
      subtitle.write('…');
    }

    return ListTile(
      title: Text(practice.companyName),
      subtitle: Text(subtitle.toString().trim()),
      isThreeLine: true,
      trailing: config != null
          ? Chip(
              label: Text(
                '${config!.ratesMonitored} · ${config!.followUpMode.shortLabel}',
              ),
              backgroundColor: ProjectColors.calc.withValues(alpha: 0.12),
            )
          : const Icon(Icons.chevron_right),
      onTap: config != null ? null : onActivate,
    );
  }
}

class _InstallmentMonitorPlanDialog extends StatefulWidget {
  const _InstallmentMonitorPlanDialog({
    required this.practice,
    this.initialPlan,
  });

  final InstallmentMonitorPractice practice;
  final InstallmentMonitorPlan? initialPlan;

  bool get isEdit => initialPlan != null;

  @override
  State<_InstallmentMonitorPlanDialog> createState() =>
      _InstallmentMonitorPlanDialogState();
}

class _InstallmentMonitorPlanDialogState
    extends State<_InstallmentMonitorPlanDialog> {
  late int _selectedRates;
  InstallmentMonitorFollowUpMode _mode =
      InstallmentMonitorFollowUpMode.telefonico;
  final _addressCtrl = TextEditingController();
  bool _loadingAddress = true;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialPlan;
    _selectedRates = initial?.ratesToMonitor ??
        widget.practice.totalRates.clamp(1, widget.practice.totalRates);
    _mode = initial?.followUpMode ?? InstallmentMonitorFollowUpMode.telefonico;
    if (initial != null && initial.visitAddress.trim().isNotEmpty) {
      _addressCtrl.text = initial.visitAddress.trim();
    }
    if (_mode == InstallmentMonitorFollowUpMode.domiciliare &&
        _addressCtrl.text.trim().isEmpty) {
      _loadAddress();
    } else {
      _loadingAddress = false;
    }
  }

  @override
  void dispose() {
    _addressCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAddress() async {
    final address = await CreditorVisitAddressService.lookupAddress(
      creditorId: widget.practice.creditorId,
    );
    if (!mounted) return;
    if (address != null && address.isNotEmpty) {
      _addressCtrl.text = address;
    }
    setState(() => _loadingAddress = false);
  }

  void _confirm() {
    if (_mode == InstallmentMonitorFollowUpMode.domiciliare &&
        _addressCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Inserisci l\'indirizzo per la visita domiciliare.'),
        ),
      );
      return;
    }

    Navigator.pop(
      context,
      InstallmentMonitorPlan(
        ratesToMonitor: _selectedRates,
        followUpMode: _mode,
        visitAddress: _addressCtrl.text,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final practice = widget.practice;

    return AlertDialog(
      title: Text(
        widget.isEdit ? 'Modifica monitoraggio' : 'Pianifica monitoraggio',
      ),
      content: SizedBox(
        width: Dimensions.dialogWidth(context, max: 440),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '${practice.companyName}\n${practice.creditorName}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              Text(
                practice.pdrInstallments.isNotEmpty
                    ? 'Rate del rateizzo: ${practice.totalRates}'
                    : 'Rate in provvigioni: ${practice.totalRates}',
                style: const TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 16),
              const Text('Tipo di sollecito'),
              const SizedBox(height: 8),
              if (Dimensions.isPhone(context))
                DropdownButtonFormField<InstallmentMonitorFollowUpMode>(
                  value: _mode,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: InstallmentMonitorFollowUpMode.telefonico,
                      child: Text('Sollecito telefonico'),
                    ),
                    DropdownMenuItem(
                      value: InstallmentMonitorFollowUpMode.domiciliare,
                      child: Text('Visita domiciliare'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _mode = value);
                  },
                )
              else
                SegmentedButton<InstallmentMonitorFollowUpMode>(
                  segments: const [
                    ButtonSegment(
                      value: InstallmentMonitorFollowUpMode.telefonico,
                      label: Text('Telefonico'),
                      icon: Icon(Icons.phone_in_talk_outlined),
                    ),
                    ButtonSegment(
                      value: InstallmentMonitorFollowUpMode.domiciliare,
                      label: Text('Domiciliare'),
                      icon: Icon(Icons.home_work_outlined),
                    ),
                  ],
                  selected: {_mode},
                  onSelectionChanged: (values) {
                    setState(() => _mode = values.first);
                  },
                ),
              const SizedBox(height: 8),
              Text(
                _mode == InstallmentMonitorFollowUpMode.telefonico
                    ? 'Crea un promemoria con notifica per richiamare il debitore '
                        'alla scadenza PDR.'
                    : 'Inserisce un appuntamento in Itinerario alla scadenza PDR, '
                        'con notifica locale.',
                style: const TextStyle(color: Colors.black54, height: 1.4),
              ),
              if (_mode == InstallmentMonitorFollowUpMode.domiciliare) ...[
                const SizedBox(height: 12),
                if (_loadingAddress)
                  const LinearProgressIndicator()
                else
                  AddressFieldWithScan(
                    controller: _addressCtrl,
                    labelText: 'Indirizzo visita',
                  ),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  const Text('Rate da monitorare'),
                  const Spacer(),
                  Text(
                    '$_selectedRates / ${practice.totalRates}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              Slider(
                value: _selectedRates.toDouble(),
                min: 1,
                max: practice.totalRates.toDouble(),
                divisions:
                    practice.totalRates > 1 ? practice.totalRates - 1 : 1,
                label: '$_selectedRates',
                onChanged: (v) => setState(() => _selectedRates = v.round()),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annulla'),
        ),
        FilledButton(
          onPressed: _confirm,
          child: Text(widget.isEdit ? 'Salva modifiche' : 'Attiva monitoraggio'),
        ),
      ],
    );
  }
}
