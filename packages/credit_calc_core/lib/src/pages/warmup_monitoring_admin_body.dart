import 'dart:async';

import 'package:flutter/material.dart';

import '../warmup/warmup_contestazioni_training_admin_service.dart';
import '../warmup/warmup_contestazioni_training_config_service.dart';
import '../warmup/warmup_contestazioni_training_defaults.dart';
import '../warmup/warmup_telefonata_admin_service.dart';
import '../warmup/warmup_telefonata_config_service.dart';
import '../warmup/warmup_telefonata_defaults.dart';

typedef WarmupMonitoringAdminVerifier = Future<bool> Function({
  bool forceRefresh,
});

/// Monitoraggio warm-up telefonata e contestazioni (BackOffice app e web).
class WarmupMonitoringAdminBody extends StatefulWidget {
  const WarmupMonitoringAdminBody({
    super.key,
    required this.verifyAdmin,
  });

  final WarmupMonitoringAdminVerifier verifyAdmin;

  @override
  State<WarmupMonitoringAdminBody> createState() =>
      _WarmupMonitoringAdminBodyState();
}

class _WarmupMonitoringAdminBodyState extends State<WarmupMonitoringAdminBody>
    with SingleTickerProviderStateMixin {
  bool _checkingAdmin = true;
  bool _isAdmin = false;
  bool _saving = false;
  bool _formDirty = false;
  String? _formError;
  late final TabController _tabs;

  final Map<String, Map<String, dynamic>> _phasePayloads = {};
  final Map<String, Map<String, dynamic>> _itemPayloads = {};
  final ScrollController _telefonataScroll = ScrollController();
  StreamSubscription<Map<String, WarmupTelefonataPhase>>? _phasesSub;
  StreamSubscription<Map<String, WarmupContestazioneTrainingItem>>? _itemsSub;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _loadAdmin();
  }

  @override
  void dispose() {
    _phasesSub?.cancel();
    _itemsSub?.cancel();
    _telefonataScroll.dispose();
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _loadAdmin() async {
    final ok = await widget.verifyAdmin(forceRefresh: true);
    if (!mounted) return;

    if (ok) {
      _phasesSub?.cancel();
      _phasesSub = WarmupTelefonataConfigService.watchAllPhases().listen(
        (phases) {
          if (!mounted || _formDirty) return;
          setState(() {
            WarmupTelefonataAdminService.applyPhasesConfig(
              phases: {
                for (final entry in phases.entries)
                  entry.key: entry.value.toFirestoreMap(),
              },
              onPhase: (phaseKey, payload) {
                _phasePayloads[phaseKey] = payload;
              },
            );
          });
        },
      );

      _itemsSub?.cancel();
      _itemsSub =
          WarmupContestazioniTrainingConfigService.watchAllItems().listen(
        (items) {
          if (!mounted || _formDirty) return;
          setState(() {
            WarmupContestazioniTrainingAdminService.applyItemsConfig(
              items: {
                for (final entry in items.entries)
                  entry.key: entry.value.toFirestoreMap(),
              },
              onItem: (id, payload) {
                _itemPayloads[id] = payload;
              },
            );
          });
        },
      );
    }

    setState(() {
      _isAdmin = ok;
      _checkingAdmin = false;
      if (ok && _phasePayloads.isEmpty) {
        WarmupTelefonataAdminService.applyPhasesConfig(
          phases: null,
          onPhase: (phaseKey, payload) => _phasePayloads[phaseKey] = payload,
        );
      }
      if (ok && _itemPayloads.isEmpty) {
        WarmupContestazioniTrainingAdminService.applyItemsConfig(
          items: null,
          onItem: (id, payload) => _itemPayloads[id] = payload,
        );
      }
    });
  }

  Map<String, dynamic> _phasePayload(String phaseKey) {
    return _phasePayloads.putIfAbsent(
      phaseKey,
      () => WarmupTelefonataAdminService.buildPhaseFormPayload(phaseKey, null),
    );
  }

  Map<String, dynamic> _itemPayload(String id) {
    return _itemPayloads.putIfAbsent(
      id,
      () => WarmupContestazioniTrainingAdminService.buildItemFormPayload(
        id,
        null,
      ),
    );
  }

  void _updatePhase(String phaseKey, Map<String, dynamic> patch) {
    _formDirty = true;
    _phasePayloads[phaseKey] = {..._phasePayload(phaseKey), ...patch};
    setState(() {});
  }

  void _updateItem(String id, Map<String, dynamic> patch) {
    _formDirty = true;
    _itemPayloads[id] = {..._itemPayload(id), ...patch};
    setState(() {});
  }

  List<String> get _sortedPhaseKeys {
    final keys = _phasePayloads.keys.toList()
      ..sort((a, b) {
        final ao = (_phasePayload(a)['order'] as num?)?.toInt() ?? 0;
        final bo = (_phasePayload(b)['order'] as num?)?.toInt() ?? 0;
        final cmp = ao.compareTo(bo);
        if (cmp != 0) return cmp;
        return a.compareTo(b);
      });
    return keys;
  }

  List<String> get _sortedItemIds {
    final ids = _itemPayloads.keys.toList()
      ..sort((a, b) {
        final ao = (_itemPayload(a)['order'] as num?)?.toInt() ?? 0;
        final bo = (_itemPayload(b)['order'] as num?)?.toInt() ?? 0;
        final cmp = ao.compareTo(bo);
        if (cmp != 0) return cmp;
        return (_itemPayload(a)['title'] ?? '').toString().compareTo(
              (_itemPayload(b)['title'] ?? '').toString(),
            );
      });
    return ids;
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _formError = null;
    });

    try {
      await WarmupTelefonataAdminService.savePhases(
        {
          for (final key in _phasePayloads.keys) key: _phasePayload(key),
        },
        verifyAdmin: widget.verifyAdmin,
      );
      await WarmupContestazioniTrainingAdminService.saveItems(
        {
          for (final id in _itemPayloads.keys) id: _itemPayload(id),
        },
        verifyAdmin: widget.verifyAdmin,
      );
      if (!mounted) return;
      setState(() {
        _saving = false;
        _formDirty = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Warm-up salvato.')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _formError = e.toString().replaceFirst('StateError: ', '');
      });
    }
  }

  void _addPhase() {
    final key = 'fase_${DateTime.now().millisecondsSinceEpoch}';
    _formDirty = true;
    _phasePayloads[key] = WarmupTelefonataAdminService.buildPhaseFormPayload(
      key,
      {
        'phaseKey': key,
        'sectionTitle': 'Nuova fase',
        'order': _phasePayloads.length,
        'enabled': true,
        'systemPrompt': WarmupTelefonataDefaults.defaultSystemPrompt,
      },
    );
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_telefonataScroll.hasClients) return;
      _telefonataScroll.animateTo(
        _telefonataScroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Nuova fase aggiunta. Ricordati di salvare.')),
    );
  }

  void _addItem({required String contestationContext}) {
    final id = 'item_${DateTime.now().millisecondsSinceEpoch}';
    _formDirty = true;
    _itemPayloads[id] =
        WarmupContestazioniTrainingAdminService.buildItemFormPayload(
      id,
      {
        'id': id,
        'title': 'Nuova contestazione',
        'context': contestationContext,
        'order': _itemPayloads.values
            .where((item) => (item['context'] ?? 'sollecito') == contestationContext)
            .length,
        'enabled': true,
        'systemPrompt': WarmupContestazioniTrainingDefaults.defaultSystemPrompt,
      },
    );
    setState(() {});
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Nuova contestazione ($contestationContext) aggiunta. Ricordati di salvare.',
        ),
      ),
    );
  }

  void _removePhase(String phaseKey) {
    _formDirty = true;
    _phasePayloads.remove(phaseKey);
    setState(() {});
  }

  void _removeItem(String id) {
    _formDirty = true;
    _itemPayloads.remove(id);
    setState(() {});
  }

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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Text(
            'Gestisci scenari warm-up telefonata e contestazioni. Ogni fase o '
            'contestazione ha il proprio prompt AI: l\'app usa solo questi '
            'valori salvati qui.',
            style: TextStyle(color: Colors.grey.shade700, height: 1.45),
          ),
        ),
        TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: 'Telefonata'),
            Tab(text: 'Contestazioni'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabs,
            children: [
              _TelefonataTab(
                phaseKeys: _sortedPhaseKeys,
                payloadFor: _phasePayload,
                onChanged: _updatePhase,
                onAdd: _addPhase,
                onRemove: _removePhase,
                scrollController: _telefonataScroll,
              ),
              _ContestazioniTab(
                itemIds: _sortedItemIds,
                payloadFor: _itemPayload,
                onChanged: _updateItem,
                onAdd: _addItem,
                onRemove: _removeItem,
              ),
            ],
          ),
        ),
        if (_formError != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              _formError!,
              style: TextStyle(color: Colors.red.shade700),
            ),
          ),
        Padding(
          padding: const EdgeInsets.all(16),
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
            label: Text(_saving ? 'Salvataggio…' : 'Salva warm-up'),
          ),
        ),
      ],
    );
  }
}

class _TelefonataTab extends StatelessWidget {
  const _TelefonataTab({
    required this.phaseKeys,
    required this.payloadFor,
    required this.onChanged,
    required this.onAdd,
    required this.onRemove,
    required this.scrollController,
  });

  final List<String> phaseKeys;
  final Map<String, dynamic> Function(String) payloadFor;
  final void Function(String, Map<String, dynamic>) onChanged;
  final VoidCallback onAdd;
  final void Function(String) onRemove;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    return ListView(
      controller: scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.tonalIcon(
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: const Text('Nuova fase'),
          ),
        ),
        const SizedBox(height: 8),
        for (final key in phaseKeys)
          _PhaseEditorCard(
            phaseKey: key,
            payload: payloadFor(key),
            onChanged: (patch) => onChanged(key, patch),
            onRemove: () => onRemove(key),
          ),
      ],
    );
  }
}

class _ContestazioniTab extends StatefulWidget {
  const _ContestazioniTab({
    required this.itemIds,
    required this.payloadFor,
    required this.onChanged,
    required this.onAdd,
    required this.onRemove,
  });

  final List<String> itemIds;
  final Map<String, dynamic> Function(String) payloadFor;
  final void Function(String, Map<String, dynamic>) onChanged;
  final void Function({required String contestationContext}) onAdd;
  final void Function(String) onRemove;

  @override
  State<_ContestazioniTab> createState() => _ContestazioniTabState();
}

class _ContestazioniTabState extends State<_ContestazioniTab> {
  String _context = 'sollecito';

  List<String> get _filteredIds {
    return widget.itemIds.where((id) {
      final context =
          (widget.payloadFor(id)['context'] ?? 'sollecito').toString();
      return context == _context;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filteredIds = _filteredIds;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'sollecito', label: Text('Sollecito')),
            ButtonSegment(value: 'recupero', label: Text('Recupero')),
          ],
          selected: {_context},
          onSelectionChanged: (selection) {
            setState(() => _context = selection.first);
          },
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.tonalIcon(
            onPressed: () => widget.onAdd(contestationContext: _context),
            icon: const Icon(Icons.add),
            label: const Text('Nuova contestazione'),
          ),
        ),
        const SizedBox(height: 8),
        if (filteredIds.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text(
              'Nessuna contestazione per $_context.',
              style: TextStyle(color: Colors.grey.shade700),
            ),
          ),
        for (final id in filteredIds)
          _ContestationEditorCard(
            itemId: id,
            payload: widget.payloadFor(id),
            onChanged: (patch) => widget.onChanged(id, patch),
            onRemove: () => widget.onRemove(id),
          ),
      ],
    );
  }
}

class _PhaseEditorCard extends StatelessWidget {
  const _PhaseEditorCard({
    required this.phaseKey,
    required this.payload,
    required this.onChanged,
    required this.onRemove,
  });

  final String phaseKey;
  final Map<String, dynamic> payload;
  final ValueChanged<Map<String, dynamic>> onChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final title = (payload['sectionTitle'] ?? phaseKey).toString();
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text('Chiave: $phaseKey'),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              children: [
                _textField('Titolo sezione', 'sectionTitle', phaseKey, payload, onChanged),
                _textField('Gruppo UI (es. Presentazione)', 'group', phaseKey, payload, onChanged),
                _numberField('Ordine', 'order', phaseKey, payload, onChanged),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Abilitata'),
                  value: payload['enabled'] != false,
                  onChanged: (v) => onChanged({'enabled': v}),
                ),
                _textField('Risposta cliente', 'customerLine', phaseKey, payload, onChanged, maxLines: 2),
                _textField('Decodifica', 'decodifica', phaseKey, payload, onChanged, maxLines: 3),
                _textField('Spiegazione', 'spiegazione', phaseKey, payload, onChanged, maxLines: 3),
                _textField('Criterio valutazione', 'evaluationCriteria', phaseKey, payload, onChanged, maxLines: 4),
                _textField('Guida operatore', 'responseGuidance', phaseKey, payload, onChanged, maxLines: 3),
                _textField('Debitore', 'targetPersonName', phaseKey, payload, onChanged),
                _textField('Mandante', 'callingOnBehalfOf', phaseKey, payload, onChanged),
                _textField(
                  'Prompt AI di sistema (solo questa fase)',
                  'systemPrompt',
                  phaseKey,
                  payload,
                  onChanged,
                  maxLines: 8,
                ),
                _textField(
                  'Istruzioni AI fase (solo questa fase)',
                  'phaseInstruction',
                  phaseKey,
                  payload,
                  onChanged,
                  maxLines: 8,
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: onRemove,
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Rimuovi fase'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ContestationEditorCard extends StatelessWidget {
  const _ContestationEditorCard({
    required this.itemId,
    required this.payload,
    required this.onChanged,
    required this.onRemove,
  });

  final String itemId;
  final Map<String, dynamic> payload;
  final ValueChanged<Map<String, dynamic>> onChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final title = (payload['title'] ?? itemId).toString();
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text('ID: $itemId · ${payload['context']}'),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              children: [
                _textField('Titolo', 'title', itemId, payload, onChanged),
                _textField('Sottotitolo', 'subtitle', itemId, payload, onChanged, maxLines: 2),
                _dropdown(
                  'Contesto',
                  'context',
                  payload,
                  onChanged,
                  const ['sollecito', 'recupero'],
                ),
                _dropdown(
                  'Categoria',
                  'category',
                  payload,
                  onChanged,
                  const ['amministrativa', 'legale', 'generica', 'economica'],
                ),
                _numberField('Ordine', 'order', itemId, payload, onChanged),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Abilitata'),
                  value: payload['enabled'] != false,
                  onChanged: (v) => onChanged({'enabled': v}),
                ),
                _textField('Dichiarazione cliente', 'declared', itemId, payload, onChanged, maxLines: 3),
                _textField('Significato', 'meaning', itemId, payload, onChanged, maxLines: 3),
                _textField('Rischio', 'risk', itemId, payload, onChanged, maxLines: 3),
                _textField('Obiettivo', 'objective', itemId, payload, onChanged, maxLines: 3),
                _textField('Risposta corretta', 'response', itemId, payload, onChanged, maxLines: 3),
                _textField(
                  'Prompt AI di sistema (solo questa contestazione)',
                  'systemPrompt',
                  itemId,
                  payload,
                  onChanged,
                  maxLines: 8,
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: onRemove,
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Rimuovi contestazione'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Widget _textField(
  String label,
  String key,
  String ownerId,
  Map<String, dynamic> payload,
  ValueChanged<Map<String, dynamic>> onChanged, {
  int maxLines = 1,
}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      key: ValueKey('$ownerId-$key-${payload[key]}'),
      initialValue: (payload[key] ?? '').toString(),
      minLines: maxLines,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        alignLabelWithHint: maxLines > 1,
      ),
      onChanged: (value) => onChanged({key: value}),
    ),
  );
}

Widget _numberField(
  String label,
  String key,
  String ownerId,
  Map<String, dynamic> payload,
  ValueChanged<Map<String, dynamic>> onChanged,
) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      key: ValueKey('$ownerId-$key-num-${payload[key]}'),
      initialValue: (payload[key] ?? 0).toString(),
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      onChanged: (value) => onChanged({key: int.tryParse(value) ?? 0}),
    ),
  );
}

Widget _dropdown(
  String label,
  String key,
  Map<String, dynamic> payload,
  ValueChanged<Map<String, dynamic>> onChanged,
  List<String> options,
) {
  final current = (payload[key] ?? options.first).toString();
  return Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: DropdownButtonFormField<String>(
      value: options.contains(current) ? current : options.first,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      items: [
        for (final option in options)
          DropdownMenuItem(value: option, child: Text(option)),
      ],
      onChanged: (value) {
        if (value != null) onChanged({key: value});
      },
    ),
  );
}
