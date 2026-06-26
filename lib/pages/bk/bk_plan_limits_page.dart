import 'package:credit_calc_core/credit_calc_core.dart';
import 'package:flutter/material.dart';

import '../../core/admin/bk_admin_service.dart';
import '../../core/admin/plan_limits_admin_service.dart';
import '../area/personal_area_shell.dart';

/// Backoffice — limiti utilizzo per piano Gratis / Plus / Enterprise.
class BkPlanLimitsPage extends StatefulWidget {
  const BkPlanLimitsPage({super.key});

  @override
  State<BkPlanLimitsPage> createState() => _BkPlanLimitsPageState();
}

class _BkPlanLimitsPageState extends State<BkPlanLimitsPage>
    with SingleTickerProviderStateMixin {
  static const _planIds = ['free', 'plus', 'enterprise'];

  bool _checkingAdmin = true;
  bool _isAdmin = false;
  bool _saving = false;
  String? _formError;
  bool _hydrated = false;
  late final TabController _tabs;

  final Map<String, PublicPlanEnforcement> _enforcement = {};
  final Map<String, bool> _unlimitedHistory = {};
  final Map<String, bool> _advancedAnalytics = {};
  final Map<String, bool> _availableNow = {};
  final Map<String, Map<String, TextEditingController>> _fields = {};
  final Map<String, TextEditingController> _tierLabel = {};
  final Map<String, TextEditingController> _name = {};
  final Map<String, TextEditingController> _price = {};
  final Map<String, TextEditingController> _description = {};

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: _planIds.length, vsync: this);
    for (final planId in _planIds) {
      _fields[planId] = {
        for (final spec in publicPlanLimitFieldSpecs)
          spec.key: TextEditingController(),
      };
      _tierLabel[planId] = TextEditingController();
      _name[planId] = TextEditingController();
      _price[planId] = TextEditingController();
      _description[planId] = TextEditingController();
    }
    _loadAdmin();
  }

  @override
  void dispose() {
    _tabs.dispose();
    for (final plan in _fields.values) {
      for (final ctrl in plan.values) {
        ctrl.dispose();
      }
    }
    for (final planId in _planIds) {
      _tierLabel[planId]?.dispose();
      _name[planId]?.dispose();
      _price[planId]?.dispose();
      _description[planId]?.dispose();
    }
    super.dispose();
  }

  Future<void> _loadAdmin() async {
    final ok = await BkAdminService.isAdmin(forceRefresh: true);
    if (!mounted) return;
    setState(() {
      _isAdmin = ok;
      _checkingAdmin = false;
    });
  }

  void _applyPlansConfig(Map<String, dynamic>? plans) {
    for (final planId in _planIds) {
      final defaults = defaultPublicPlanLimitsForPlan(planId);
      final display = defaultPublicSubscriptionPlanForId(planId);
      final raw = plans?[planId];
      final rawMap = raw is Map<String, dynamic>
          ? raw
          : raw is Map
              ? Map<String, dynamic>.from(raw)
              : null;
      final limits = rawMap != null
          ? PublicPlanLimitsFirestore.mergeFromMap(defaults, rawMap)
          : defaults;

      _enforcement[planId] = limits.enforcement;
      _unlimitedHistory[planId] = limits.unlimitedCommissionHistory;
      _advancedAnalytics[planId] = limits.advancedCommissionAnalytics;
      _availableNow[planId] = rawMap?['availableNow'] is bool
          ? rawMap!['availableNow'] as bool
          : display.availableNow;

      _tierLabel[planId]!.text =
          (rawMap?['tierLabel'] ?? defaultPublicPlanTierLabel(planId))
              .toString();
      _name[planId]!.text = (rawMap?['name'] ?? display.name).toString();
      _price[planId]!.text = (rawMap?['price'] ?? display.price).toString();
      _description[planId]!.text =
          (rawMap?['description'] ?? display.description).toString();

      for (final spec in publicPlanLimitFieldSpecs) {
        final value = readPublicPlanLimitField(limits, spec.key);
        _fields[planId]![spec.key]!.text =
            value == null ? '' : '$value';
      }
    }
  }

  PublicPlanLimits _limitsFromForm(String planId) {
    final defaults = defaultPublicPlanLimitsForPlan(planId);
    return PublicPlanLimitsFirestore.mergeFromMap(
      defaults,
      _buildPlanPayload(planId),
    );
  }

  void _generateDescriptionForPlan(String planId) {
    final limits = _limitsFromForm(planId);
    _description[planId]!.text =
        buildPublicPlanDescriptionFromLimits(limits, planId);
    setState(() {});
  }

  Map<String, dynamic> _buildPlanPayload(String planId) {
    final payload = <String, dynamic>{
      'tierLabel': _tierLabel[planId]!.text.trim(),
      'name': _name[planId]!.text.trim(),
      'price': _price[planId]!.text.trim(),
      'description': _description[planId]!.text.trim(),
      'availableNow': _availableNow[planId] ?? true,
      'enforcement': (_enforcement[planId] ?? PublicPlanEnforcement.hard).name,
      'unlimitedCommissionHistory': _unlimitedHistory[planId] ?? false,
      'advancedCommissionAnalytics': _advancedAnalytics[planId] ?? false,
    };

    for (final spec in publicPlanLimitFieldSpecs) {
      final raw = _fields[planId]![spec.key]!.text.trim();
      if (raw.isEmpty) {
        payload[spec.key] = null;
      } else {
        payload[spec.key] = int.tryParse(raw);
      }
    }
    return payload;
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _formError = null;
    });

    try {
      final plans = <String, Map<String, dynamic>>{
        for (final planId in _planIds) planId: _buildPlanPayload(planId),
      };
      await PlanLimitsAdminService.savePlans(plans);
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Piani salvati.')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _formError = e.toString().replaceFirst('StateError: ', '');
      });
    }
  }

  Future<void> _restoreDefaults() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ripristina default'),
        content: const Text(
          'Ripristinare i valori predefiniti per tutti i piani? '
          'Le modifiche salvate su Firestore verranno sovrascritte.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Ripristina'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    _applyPlansConfig(null);
    setState(() {});
  }

  String _planLabel(String planId) => switch (planId) {
        'plus' => 'Plus',
        'enterprise' => 'Enterprise',
        _ => 'Gratis',
      };

  @override
  Widget build(BuildContext context) {
    return PersonalAreaShell(
      pageTitle: 'Piani FREE / PLUS / ENTERPRISE',
      body: _checkingAdmin
          ? const Center(child: CircularProgressIndicator())
          : !_isAdmin
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Accesso riservato agli amministratori backoffice.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : StreamBuilder<Map<String, dynamic>?>(
                  stream: PublicPlanLimitsConfigService.watchPlansConfig(),
                  builder: (context, snapshot) {
                    if (!_hydrated &&
                        snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (!_hydrated &&
                        snapshot.connectionState != ConnectionState.waiting) {
                      _applyPlansConfig(snapshot.data);
                      _hydrated = true;
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                          child: Text(
                            'Configura ogni piano separatamente: testi mostrati in '
                            '«Il mio piano», prezzi e limiti operativi applicati '
                            'in CreditCalc, CreditForm e CreditJob.',
                            style: TextStyle(
                              color: Colors.grey.shade700,
                              height: 1.45,
                            ),
                          ),
                        ),
                        TabBar(
                          controller: _tabs,
                          tabs: [
                            for (final id in _planIds) Tab(text: _planLabel(id)),
                          ],
                        ),
                        Expanded(
                          child: TabBarView(
                            controller: _tabs,
                            children: [
                              for (final planId in _planIds)
                                _PlanForm(
                                  planId: planId,
                                  tierLabel: _tierLabel[planId]!,
                                  name: _name[planId]!,
                                  price: _price[planId]!,
                                  description: _description[planId]!,
                                  availableNow: _availableNow[planId] ?? true,
                                  onAvailableNowChanged: (value) => setState(
                                    () => _availableNow[planId] = value,
                                  ),
                                  enforcement: _enforcement[planId] ??
                                      PublicPlanEnforcement.hard,
                                  onEnforcementChanged: (value) => setState(
                                    () => _enforcement[planId] = value,
                                  ),
                                  unlimitedHistory:
                                      _unlimitedHistory[planId] ?? false,
                                  onUnlimitedHistoryChanged: (value) => setState(
                                    () => _unlimitedHistory[planId] = value,
                                  ),
                                  advancedAnalytics:
                                      _advancedAnalytics[planId] ?? false,
                                  onAdvancedAnalyticsChanged: (value) => setState(
                                    () => _advancedAnalytics[planId] = value,
                                  ),
                                  fields: _fields[planId]!,
                                  onGenerateDescription: () =>
                                      _generateDescriptionForPlan(planId),
                                ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (_formError != null) ...[
                                Text(
                                  _formError!,
                                  style: TextStyle(color: Colors.red.shade700),
                                ),
                                const SizedBox(height: 12),
                              ],
                              Row(
                                children: [
                                  OutlinedButton(
                                    onPressed: _saving ? null : _restoreDefaults,
                                    child: const Text('Ripristina default'),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: FilledButton.icon(
                                      onPressed: _saving ? null : _save,
                                      icon: _saving
                                          ? const SizedBox(
                                              width: 18,
                                              height: 18,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.white,
                                              ),
                                            )
                                          : const Icon(Icons.save_outlined),
                                      label: Text(
                                        _saving ? 'Salvataggio…' : 'Salva piani',
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
    );
  }
}

class _PlanForm extends StatelessWidget {
  const _PlanForm({
    required this.planId,
    required this.tierLabel,
    required this.name,
    required this.price,
    required this.description,
    required this.availableNow,
    required this.onAvailableNowChanged,
    required this.enforcement,
    required this.onEnforcementChanged,
    required this.unlimitedHistory,
    required this.onUnlimitedHistoryChanged,
    required this.advancedAnalytics,
    required this.onAdvancedAnalyticsChanged,
    required this.fields,
    required this.onGenerateDescription,
  });

  final String planId;
  final TextEditingController tierLabel;
  final TextEditingController name;
  final TextEditingController price;
  final TextEditingController description;
  final bool availableNow;
  final ValueChanged<bool> onAvailableNowChanged;
  final PublicPlanEnforcement enforcement;
  final ValueChanged<PublicPlanEnforcement> onEnforcementChanged;
  final bool unlimitedHistory;
  final ValueChanged<bool> onUnlimitedHistoryChanged;
  final bool advancedAnalytics;
  final ValueChanged<bool> onAdvancedAnalyticsChanged;
  final Map<String, TextEditingController> fields;
  final VoidCallback onGenerateDescription;

  @override
  Widget build(BuildContext context) {
    final isEnterprise = planId == 'enterprise';

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  controller: tierLabel,
                  decoration: const InputDecoration(
                    labelText: 'Etichetta card (es. FREE)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: name,
                  decoration: const InputDecoration(
                    labelText: 'Nome piano',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: price,
                  decoration: const InputDecoration(
                    labelText: 'Prezzo mostrato',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: description,
                  minLines: 5,
                  maxLines: 12,
                  decoration: const InputDecoration(
                    labelText: 'Descrizione (come in «Il mio piano»)',
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: onGenerateDescription,
                    icon: const Icon(Icons.auto_fix_high_outlined, size: 18),
                    label: const Text('Genera descrizione dai limiti'),
                  ),
                ),
                if (planId != 'free')
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Disponibile per acquisto'),
                    value: availableNow,
                    onChanged: onAvailableNowChanged,
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DropdownButtonFormField<PublicPlanEnforcement>(
                  value: enforcement,
                  decoration: const InputDecoration(
                    labelText: 'Modalità enforcement',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: PublicPlanEnforcement.hard,
                      child: Text('Hard — blocco al limite'),
                    ),
                    DropdownMenuItem(
                      value: PublicPlanEnforcement.soft,
                      child: Text('Soft — avviso all\'80%'),
                    ),
                    DropdownMenuItem(
                      value: PublicPlanEnforcement.fairUse,
                      child: Text('Fair use — senza limiti operativi'),
                    ),
                  ],
                  onChanged: isEnterprise
                      ? null
                      : (value) {
                          if (value != null) onEnforcementChanged(value);
                        },
                ),
                if (isEnterprise)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Enterprise usa fair use; i campi numerici sono ignorati.',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        for (final area in PublicPlanLimitArea.values) ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    publicPlanLimitAreaLabel(area),
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 12),
                  for (var i = 0;
                      i < publicPlanLimitFieldsForArea(area).length;
                      i++) ...[
                    if (i > 0) const SizedBox(height: 12),
                    Builder(
                      builder: (context) {
                        final spec = publicPlanLimitFieldsForArea(area)[i];
                        return TextField(
                          controller: fields[spec.key],
                          keyboardType: TextInputType.number,
                          enabled: !isEnterprise,
                          decoration: InputDecoration(
                            labelText: spec.label,
                            helperText: spec.periodHint,
                            border: const OutlineInputBorder(),
                          ),
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        Card(
          child: SwitchListTile(
            title: const Text('Storico provvigioni illimitato'),
            value: unlimitedHistory,
            onChanged: (value) => onUnlimitedHistoryChanged(value),
          ),
        ),
        Card(
          child: SwitchListTile(
            title: const Text('Analytics provvigioni avanzate'),
            value: advancedAnalytics,
            onChanged: (value) => onAdvancedAnalyticsChanged(value),
          ),
        ),
      ],
    );
  }
}
