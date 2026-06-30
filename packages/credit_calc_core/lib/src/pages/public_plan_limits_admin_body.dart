import 'dart:async';

import 'package:flutter/material.dart';

import '../subscription/public_plan_limits.dart';
import '../subscription/public_plan_limits_admin_service.dart';
import '../subscription/public_plan_limits_config_service.dart';

/// Editor piani FREE / PLUS / ENTERPRISE (BackOffice app e web).
class PublicPlanLimitsAdminBody extends StatefulWidget {
  const PublicPlanLimitsAdminBody({
    super.key,
    required this.verifyAdmin,
  });

  final PublicPlanLimitsAdminVerifier verifyAdmin;

  @override
  State<PublicPlanLimitsAdminBody> createState() =>
      _PublicPlanLimitsAdminBodyState();
}

class _PublicPlanLimitsAdminBodyState extends State<PublicPlanLimitsAdminBody>
    with SingleTickerProviderStateMixin {
  bool _checkingAdmin = true;
  bool _isAdmin = false;
  bool _saving = false;
  String? _formError;
  String? _loadWarning;
  late final TabController _tabs;
  StreamSubscription<Map<String, dynamic>?>? _plansSubscription;
  bool _formDirty = false;

  final Map<String, Map<String, dynamic>> _planPayloads = {};

  @override
  void initState() {
    super.initState();
    _tabs = TabController(
      length: PublicPlanLimitsAdminService.planIds.length,
      vsync: this,
    );
    _loadAdmin();
  }

  @override
  void dispose() {
    _plansSubscription?.cancel();
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _loadAdmin() async {
    final ok = await widget.verifyAdmin(forceRefresh: true);
    if (!mounted) return;

    if (ok) {
      await _refreshFromFirestore();
      _plansSubscription?.cancel();
      _plansSubscription =
          PublicPlanLimitsConfigService.watchPlansConfig().listen(
        (plans) {
          // Non sovrascrivere modifiche locali mentre l'admin sta editando.
          if (!mounted || _formDirty) return;
          setState(() {
            _loadWarning = null;
            _applyPlansConfig(plans);
          });
        },
        onError: (_) {
          if (!mounted) return;
          setState(() {
            _loadWarning ??=
                'Impossibile sincronizzare da Firestore. '
                'Modifica e salva per creare il documento.';
          });
        },
      );
    }

    setState(() {
      _isAdmin = ok;
      _checkingAdmin = false;
    });
  }

  Future<void> _refreshFromFirestore() async {
    try {
      final plans = await PublicPlanLimitsConfigService.fetchPlansConfig();
      if (!mounted) return;
      setState(() {
        _loadWarning = null;
        _formDirty = false;
        _applyPlansConfig(plans);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadWarning ??=
            'Lettura Firestore non riuscita. '
            'Controlla connessione e regole, poi riprova.';
      });
    }
  }

  void _applyPlansConfig(Map<String, dynamic>? plans) {
    PublicPlanLimitsAdminService.applyPlansConfig(
      plans: plans,
      onPlan: (planId, payload) {
        _planPayloads[planId] = {...payload, 'planId': planId};
      },
    );
  }

  Map<String, dynamic> _payloadFor(String planId) {
    return _planPayloads.putIfAbsent(
      planId,
      () => PublicPlanLimitsAdminService.buildPlanFormPayload(planId, null)
        ..['planId'] = planId,
    );
  }

  void _updatePayload(
    String planId,
    Map<String, dynamic> patch, {
    bool forceRebuild = false,
  }) {
    _formDirty = true;
    _planPayloads[planId] = {
      ..._payloadFor(planId),
      ...patch,
      'planId': planId,
    };
    if (forceRebuild || _patchNeedsRebuild(patch) || _patchAffectsPreview(patch)) {
      setState(() {});
    }
  }

  bool _patchAffectsPreview(Map<String, dynamic> patch) {
    if (patch.containsKey('limitLinesText')) return true;
    return patch.keys.any((key) => key.startsWith('field:'));
  }

  bool _patchNeedsRebuild(Map<String, dynamic> patch) {
    return patch.keys.any(
      (key) =>
          key == 'enforcement' ||
          key == 'availableNow' ||
          key == 'unlimitedCommissionHistory' ||
          key == 'advancedCommissionAnalytics',
    );
  }

  void _generateDescriptionForPlan(String planId) {
    final generated = PublicPlanLimitsAdminService.generateTextsForPlan(
      planId,
      _payloadFor(planId),
    );
    _updatePayload(planId, generated, forceRebuild: true);
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _formError = null;
    });

    try {
      final plans = <String, Map<String, dynamic>>{
        for (final planId in PublicPlanLimitsAdminService.planIds)
          planId: PublicPlanLimitsAdminService.buildFirestorePlanPayload(
            planId,
            _payloadFor(planId),
          ),
      };
      await PublicPlanLimitsAdminService.savePlans(
        plans,
        verifyAdmin: widget.verifyAdmin,
      );
      if (!mounted) return;
      setState(() {
        _saving = false;
        _formDirty = false;
      });
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
    setState(() {
      _formDirty = true;
    });
  }

  String _planLabel(String planId) => switch (planId) {
        'plus' => 'Plus',
        'enterprise' => 'Enterprise',
        _ => 'Gratis',
      };

  @override
  Widget build(BuildContext context) {
    if (_checkingAdmin) {
      return const Center(child: CircularProgressIndicator());
    }

    if (!_isAdmin) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Accesso riservato agli amministratori backoffice.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return _buildEditor(context);
  }

  Widget _buildEditor(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Configura ogni piano separatamente: testi mostrati in '
                '«Il mio piano», prezzi e limiti operativi applicati '
                'in CreditCalc, CreditForm e CreditJob.',
                style: TextStyle(
                  color: Colors.grey.shade700,
                  height: 1.45,
                ),
              ),
              if (_loadWarning != null) ...[
                const SizedBox(height: 12),
                MaterialBanner(
                  content: Text(_loadWarning!),
                  leading: const Icon(Icons.cloud_off_outlined),
                  backgroundColor: Colors.orange.shade50,
                  actions: [
                    TextButton(
                      onPressed: _refreshFromFirestore,
                      child: const Text('Riprova'),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        TabBar(
          controller: _tabs,
          tabs: [
            for (final id in PublicPlanLimitsAdminService.planIds)
              Tab(text: _planLabel(id)),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabs,
            children: [
                  for (final planId in PublicPlanLimitsAdminService.planIds)
                    _PublicPlanLimitsPlanForm(
                      key: ValueKey('plan-form-$planId'),
                      planId: planId,
                  payload: _payloadFor(planId),
                  onChanged: (patch) => _updatePayload(planId, patch),
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
  }
}

class _PublicPlanLimitsPlanForm extends StatefulWidget {
  const _PublicPlanLimitsPlanForm({
    super.key,
    required this.planId,
    required this.payload,
    required this.onChanged,
    required this.onGenerateDescription,
  });

  final String planId;
  final Map<String, dynamic> payload;
  final ValueChanged<Map<String, dynamic>> onChanged;
  final VoidCallback onGenerateDescription;

  @override
  State<_PublicPlanLimitsPlanForm> createState() =>
      _PublicPlanLimitsPlanFormState();
}

class _PublicPlanLimitsPlanFormState extends State<_PublicPlanLimitsPlanForm> {
  late final TextEditingController _tierLabel;
  late final TextEditingController _name;
  late final TextEditingController _price;
  late final TextEditingController _description;
  late final TextEditingController _limitLines;
  late final Map<String, TextEditingController> _fields;

  @override
  void initState() {
    super.initState();
    _tierLabel = TextEditingController();
    _name = TextEditingController();
    _price = TextEditingController();
    _description = TextEditingController();
    _limitLines = TextEditingController();
    _fields = {
      for (final spec in publicPlanLimitFieldSpecs)
        spec.key: TextEditingController(),
    };
    _syncFromPayload();
  }

  @override
  void didUpdateWidget(covariant _PublicPlanLimitsPlanForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.planId != widget.planId ||
        oldWidget.payload != widget.payload) {
      _syncFromPayload();
    }
  }

  void _setControllerText(TextEditingController controller, String value) {
    if (controller.text == value) return;
    final offset = controller.selection.isValid
        ? controller.selection.baseOffset
        : value.length;
    controller.value = controller.value.copyWith(
      text: value,
      selection: TextSelection.collapsed(
        offset: offset.clamp(0, value.length),
      ),
      composing: TextRange.empty,
    );
  }

  void _syncFromPayload() {
    final payload = widget.payload;
    _setControllerText(_tierLabel, payload['tierLabel'] as String? ?? '');
    _setControllerText(_name, payload['name'] as String? ?? '');
    _setControllerText(_price, payload['price'] as String? ?? '');
    _setControllerText(_description, payload['description'] as String? ?? '');
    _setControllerText(_limitLines, payload['limitLinesText'] as String? ?? '');
    for (final spec in publicPlanLimitFieldSpecs) {
      _setControllerText(
        _fields[spec.key]!,
        payload['field:${spec.key}'] as String? ?? '',
      );
    }
  }

  void _emit({bool refreshLimitLines = false}) {
    final patch = _collectPatch();
    if (refreshLimitLines) {
      _applyRefreshedLimitLines(patch);
    }
    widget.onChanged(patch);
  }

  Map<String, dynamic> _collectPatch() {
    return {
      'tierLabel': _tierLabel.text,
      'name': _name.text,
      'price': _price.text,
      'description': _description.text,
      'limitLinesText': _limitLines.text,
      for (final spec in publicPlanLimitFieldSpecs)
        'field:${spec.key}': _fields[spec.key]!.text,
    };
  }

  void _applyRefreshedLimitLines(Map<String, dynamic> patch) {
    final merged = {...widget.payload, ...patch};
    final limits = PublicPlanLimitsAdminService.limitsFromPayload(
      widget.planId,
      merged,
    );
    final lines =
        buildPublicPlanLimitListItems(limits, widget.planId).join('\n');
    _setControllerText(_limitLines, lines);
    patch['limitLinesText'] = lines;
  }

  void _patchWithRefreshedList(Map<String, dynamic> extra) {
    final patch = {..._collectPatch(), ...extra};
    _applyRefreshedLimitLines(patch);
    widget.onChanged(patch);
  }

  @override
  void dispose() {
    _tierLabel.dispose();
    _name.dispose();
    _price.dispose();
    _description.dispose();
    _limitLines.dispose();
    for (final ctrl in _fields.values) {
      ctrl.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEnterprise = widget.planId == 'enterprise';
    final enforcement =
        widget.payload['enforcement'] as PublicPlanEnforcement? ??
            PublicPlanEnforcement.hard;
    final availableNow = widget.payload['availableNow'] == true;
    final unlimitedHistory =
        widget.payload['unlimitedCommissionHistory'] == true;
    final advancedAnalytics =
        widget.payload['advancedCommissionAnalytics'] == true;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  controller: _tierLabel,
                  onChanged: (_) => _emit(),
                  decoration: const InputDecoration(
                    labelText: 'Etichetta card (es. FREE)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _name,
                  onChanged: (_) => _emit(),
                  decoration: const InputDecoration(
                    labelText: 'Nome piano',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _price,
                  onChanged: (_) => _emit(),
                  decoration: const InputDecoration(
                    labelText: 'Prezzo mostrato',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _description,
                  onChanged: (_) => _emit(),
                  minLines: 3,
                  maxLines: 8,
                  decoration: const InputDecoration(
                    labelText: 'Intro descrizione (primo paragrafo in card)',
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _limitLines,
                  onChanged: (_) => _emit(),
                  minLines: 5,
                  maxLines: 14,
                  decoration: const InputDecoration(
                    labelText: 'Elenco limiti (una riga per punto)',
                    alignLabelWithHint: true,
                    helperText:
                        'Mostrato come elenco numerato in «Il mio piano». '
                        'I valori numerici sotto regolano i limiti operativi reali.',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: widget.onGenerateDescription,
                    icon: const Icon(Icons.auto_fix_high_outlined, size: 18),
                    label: const Text('Genera intro ed elenco dai limiti'),
                  ),
                ),
                if (widget.planId != 'free')
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Disponibile per acquisto'),
                    value: availableNow,
                    onChanged: (value) =>
                        widget.onChanged({'availableNow': value}),
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
                          if (value != null) {
                            _patchWithRefreshedList({'enforcement': value});
                          }
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
                          controller: _fields[spec.key],
                          onChanged: (_) => _emit(refreshLimitLines: true),
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
            onChanged: (value) => _patchWithRefreshedList(
              {'unlimitedCommissionHistory': value},
            ),
          ),
        ),
        Card(
          child: SwitchListTile(
            title: const Text('Analytics provvigioni avanzate'),
            value: advancedAnalytics,
            onChanged: (value) => _patchWithRefreshedList(
              {'advancedCommissionAnalytics': value},
            ),
          ),
        ),
      ],
    );
  }
}
