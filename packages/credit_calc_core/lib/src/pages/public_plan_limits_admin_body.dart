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
    with TickerProviderStateMixin {
  bool _checkingAdmin = true;
  bool _isAdmin = false;
  bool _saving = false;
  String? _formError;
  String? _loadWarning;
  late TabController _tabs;
  StreamSubscription<
      ({Map<String, dynamic>? users, Map<String, dynamic>? companies})>? _plansSubscription;
  bool _userFormDirty = false;
  bool _companyFormDirty = false;
  PublicPlanLimitsAudience _audience = PublicPlanLimitsAudience.users;

  final Map<String, Map<String, dynamic>> _userPlanPayloads = {};
  final Map<String, Map<String, dynamic>> _companyPlanPayloads = {};

  List<String> get _currentPlanIds => _audience == PublicPlanLimitsAudience.users
      ? PublicPlanLimitsAdminService.planIds
      : PublicPlanLimitsAdminService.companyPlanIds;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(
      length: _currentPlanIds.length,
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

  void _switchAudience(PublicPlanLimitsAudience audience) {
    if (_audience == audience) return;
    final previousIndex = _tabs.index;
    _tabs.dispose();
    _audience = audience;
    _tabs = TabController(
      length: _currentPlanIds.length,
      vsync: this,
      initialIndex: previousIndex.clamp(0, _currentPlanIds.length - 1),
    );
    setState(() {});
  }

  Future<void> _loadAdmin() async {
    final ok = await widget.verifyAdmin(forceRefresh: true);
    if (!mounted) return;

    if (ok) {
      await _refreshFromFirestore();
      _plansSubscription?.cancel();
      _plansSubscription =
          PublicPlanLimitsConfigService.watchAdminPlansBundle().listen(
        (bundle) {
          if (!mounted || _userFormDirty || _companyFormDirty) return;
          setState(() {
            _loadWarning = null;
            _applyPlansConfig(bundle.users);
            _applyCompanyPlansConfig(bundle.companies);
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
      final bundle = await PublicPlanLimitsConfigService.fetchAdminPlansBundle();
      if (!mounted) return;
      setState(() {
        _loadWarning = null;
        _userFormDirty = false;
        _companyFormDirty = false;
        _applyPlansConfig(bundle.users);
        _applyCompanyPlansConfig(bundle.companies);
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
        _userPlanPayloads[planId] = {...payload, 'planId': planId};
      },
    );
  }

  void _applyCompanyPlansConfig(Map<String, dynamic>? plans) {
    PublicPlanLimitsAdminService.applyCompanyPlansConfig(
      plans: plans,
      onPlan: (planId, payload) {
        _companyPlanPayloads[planId] = {...payload, 'planId': planId};
      },
    );
  }

  Map<String, dynamic> _payloadFor(String planId) {
    final payloads = _audience == PublicPlanLimitsAudience.users
        ? _userPlanPayloads
        : _companyPlanPayloads;
    return payloads.putIfAbsent(
      planId,
      () => (_audience == PublicPlanLimitsAudience.users
              ? PublicPlanLimitsAdminService.buildPlanFormPayload(planId, null)
              : PublicPlanLimitsAdminService.buildCompanyPlanFormPayload(
                  planId,
                  null,
                ))
        ..['planId'] = planId,
    );
  }

  void _updatePayload(
    String planId,
    Map<String, dynamic> patch, {
    bool forceRebuild = false,
  }) {
    if (_audience == PublicPlanLimitsAudience.users) {
      _userFormDirty = true;
    } else {
      _companyFormDirty = true;
    }
    final payloads = _audience == PublicPlanLimitsAudience.users
        ? _userPlanPayloads
        : _companyPlanPayloads;
    payloads[planId] = {
      ..._payloadFor(planId),
      ...patch,
      'planId': planId,
    };
    if (_audience == PublicPlanLimitsAudience.companies ||
        forceRebuild ||
        _patchNeedsRebuild(patch) ||
        _patchAffectsPreview(patch)) {
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
    final generated = _audience == PublicPlanLimitsAudience.users
        ? PublicPlanLimitsAdminService.generateTextsForPlan(
            planId,
            _payloadFor(planId),
          )
        : PublicPlanLimitsAdminService.generateTextsForCompanyPlan(
            planId,
            _payloadFor(planId),
          );
    _updatePayload(planId, generated, forceRebuild: true);
  }

  Map<String, dynamic> _userPayloadForSave(String planId) {
    return _userPlanPayloads.putIfAbsent(
      planId,
      () => PublicPlanLimitsAdminService.buildPlanFormPayload(planId, null)
        ..['planId'] = planId,
    );
  }

  Map<String, dynamic> _companyPayloadForSave(String planId) {
    return _companyPlanPayloads.putIfAbsent(
      planId,
      () =>
          PublicPlanLimitsAdminService.buildCompanyPlanFormPayload(planId, null)
            ..['planId'] = planId,
    );
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
            _userPayloadForSave(planId),
          ),
      };
      final companyPlans = <String, Map<String, dynamic>>{
        for (final planId in PublicPlanLimitsAdminService.companyPlanIds)
          planId: PublicPlanLimitsAdminService.buildCompanyFirestorePlanPayload(
            planId,
            _companyPayloadForSave(planId),
          ),
      };
      await PublicPlanLimitsAdminService.savePlans(
        plans,
        companyPlans: companyPlans,
        verifyAdmin: widget.verifyAdmin,
      );
      if (!mounted) return;
      setState(() {
        _saving = false;
        _userFormDirty = false;
        _companyFormDirty = false;
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
    final isUsers = _audience == PublicPlanLimitsAudience.users;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ripristina default'),
        content: Text(
          isUsers
              ? 'Ripristinare i valori predefiniti per tutti i piani utente? '
                  'Le modifiche salvate su Firestore verranno sovrascritte.'
              : 'Ripristinare i valori predefiniti per tutti i piani azienda? '
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
    if (isUsers) {
      _applyPlansConfig(null);
      setState(() => _userFormDirty = true);
    } else {
      _applyCompanyPlansConfig(null);
      setState(() => _companyFormDirty = true);
    }
  }

  String _planLabel(String planId) => switch (planId) {
        'plus' => 'Plus',
        'enterprise' => 'Enterprise',
        'starter' => 'Starter',
        'business' => 'Business',
        'professional' => 'Professional',
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
    final isUsers = _audience == PublicPlanLimitsAudience.users;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _AudienceSelector(
                isUsers: isUsers,
                onUsers: () =>
                    _switchAudience(PublicPlanLimitsAudience.users),
                onCompanies: () =>
                    _switchAudience(PublicPlanLimitsAudience.companies),
              ),
              const SizedBox(height: 12),
              Text(
                isUsers
                    ? 'Configura ogni piano utente: testi mostrati in '
                        '«Il mio piano», prezzi e limiti operativi applicati '
                        'in CreditCalc, CreditForm e CreditJob.'
                    : 'Configura ogni piano aziendale: testi mostrati in '
                        '«Il mio piano», prezzi, elenco benefici e limite '
                        'collaboratori work attivi.',
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
          isScrollable: !isUsers,
          tabs: [
            for (final id in _currentPlanIds) Tab(text: _planLabel(id)),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabs,
            children: [
              for (final planId in _currentPlanIds)
                if (isUsers)
                  _PublicPlanLimitsPlanForm(
                    key: ValueKey('user-plan-form-$planId'),
                    planId: planId,
                    payload: _payloadFor(planId),
                    onChanged: (patch) => _updatePayload(planId, patch),
                    onGenerateDescription: () =>
                        _generateDescriptionForPlan(planId),
                  )
                else
                  _CompanyPlanLimitsPlanForm(
                    key: ValueKey('company-plan-form-$planId'),
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

class _CompanyPlanLimitsPlanForm extends StatefulWidget {
  const _CompanyPlanLimitsPlanForm({
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
  State<_CompanyPlanLimitsPlanForm> createState() =>
      _CompanyPlanLimitsPlanFormState();
}

class _CompanyPlanLimitsPlanFormState extends State<_CompanyPlanLimitsPlanForm> {
  late final TextEditingController _tierLabel;
  late final TextEditingController _name;
  late final TextEditingController _price;
  late final TextEditingController _description;
  late final TextEditingController _limitLines;
  late final TextEditingController _collaboratorLimit;

  @override
  void initState() {
    super.initState();
    _tierLabel = TextEditingController();
    _name = TextEditingController();
    _price = TextEditingController();
    _description = TextEditingController();
    _limitLines = TextEditingController();
    _collaboratorLimit = TextEditingController();
    _syncFromPayload();
  }

  @override
  void didUpdateWidget(covariant _CompanyPlanLimitsPlanForm oldWidget) {
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
    _setControllerText(
      _collaboratorLimit,
      payload['collaboratorLimit'] as String? ?? '',
    );
  }

  void _emit() {
    widget.onChanged({
      'tierLabel': _tierLabel.text,
      'name': _name.text,
      'price': _price.text,
      'description': _description.text,
      'limitLinesText': _limitLines.text,
      'collaboratorLimit': _collaboratorLimit.text,
    });
  }

  @override
  void dispose() {
    _tierLabel.dispose();
    _name.dispose();
    _price.dispose();
    _description.dispose();
    _limitLines.dispose();
    _collaboratorLimit.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final availableNow = widget.payload['availableNow'] == true;

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
                    labelText: 'Etichetta card (es. STARTER)',
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
                  minLines: 3,
                  maxLines: 10,
                  decoration: const InputDecoration(
                    labelText: 'Elenco benefici (una riga per punto)',
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _collaboratorLimit,
                  onChanged: (_) => _emit(),
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Collaboratori work attivi',
                    helperText:
                        'Limite applicato all\'azienda e ai codici work collegati.',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: widget.onGenerateDescription,
                    icon: const Icon(Icons.auto_fix_high_outlined, size: 18),
                    label: const Text('Genera intro ed elenco dal limite'),
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
      ],
    );
  }
}

class _AudienceSelector extends StatelessWidget {
  const _AudienceSelector({
    required this.isUsers,
    required this.onUsers,
    required this.onCompanies,
  });

  final bool isUsers;
  final VoidCallback onUsers;
  final VoidCallback onCompanies;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFE2E8F0),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF0F4C81), width: 1.5),
      ),
      child: Row(
        children: [
          Expanded(
            child: _AudienceTab(
              label: 'Utenti',
              icon: Icons.person_outline,
              selected: isUsers,
              onTap: onUsers,
            ),
          ),
          Expanded(
            child: _AudienceTab(
              label: 'Aziende',
              icon: Icons.business_outlined,
              selected: !isUsers,
              onTap: onCompanies,
            ),
          ),
        ],
      ),
    );
  }
}

class _AudienceTab extends StatelessWidget {
  const _AudienceTab({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bg = selected ? const Color(0xFF0F4C81) : Colors.transparent;
    final fg = selected ? Colors.white : const Color(0xFF0F4C81);

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 20, color: fg),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: fg,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
