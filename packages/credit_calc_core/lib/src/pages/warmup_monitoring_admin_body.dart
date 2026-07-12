import 'dart:async';

import 'package:flutter/material.dart';

import '../warmup/warmup_contestazioni_training_admin_service.dart';
import '../warmup/warmup_contestazioni_training_config_service.dart';
import '../warmup/warmup_contestazioni_training_defaults.dart';
import '../warmup/warmup_telefonata_admin_service.dart';
import '../warmup/warmup_telefonata_config_service.dart';
import '../warmup/warmup_telefonata_defaults.dart';
import '../warmup/warmup_contestation_core.dart';
import 'warmup_contestation_admin_form_body.dart';

typedef WarmupMonitoringAdminVerifier = Future<bool> Function({
  bool forceRefresh,
});

/// Monitoraggio warm-up telefonata e contestazioni (BackOffice app e web).
class WarmupMonitoringAdminBody extends StatefulWidget {
  const WarmupMonitoringAdminBody({
    super.key,
    required this.verifyAdmin,
    this.onUtentiTabSeen,
  });

  final WarmupMonitoringAdminVerifier verifyAdmin;
  final VoidCallback? onUtentiTabSeen;

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
  String? _actionError;
  int _selectedTab = 0;
  bool _utentiTabSeenNotified = false;
  static const int _utentiTabIndex = 3;
  late final TabController _tabs;
  late final VoidCallback _tabListener;

  final Map<String, Map<String, dynamic>> _phasePayloads = {};
  final Map<String, Map<String, dynamic>> _itemPayloads = {};
  final ScrollController _telefonataScroll = ScrollController();
  StreamSubscription<Map<String, WarmupTelefonataPhase>>? _phasesSub;
  StreamSubscription<Map<String, WarmupContestazioneTrainingItem>>? _itemsSub;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
    _tabListener = () {
      if (!_tabs.indexIsChanging && _selectedTab != _tabs.index) {
        setState(() => _selectedTab = _tabs.index);
      }
      if (!_tabs.indexIsChanging && _tabs.index == _utentiTabIndex) {
        _notifyUtentiTabSeen();
      }
    };
    _tabs.addListener(_tabListener);
    _loadAdmin();
  }

  @override
  void dispose() {
    _phasesSub?.cancel();
    _itemsSub?.cancel();
    _telefonataScroll.dispose();
    _tabs.removeListener(_tabListener);
    _tabs.dispose();
    super.dispose();
  }

  void _notifyUtentiTabSeen() {
    if (_utentiTabSeenNotified) return;
    _utentiTabSeenNotified = true;
    widget.onUtentiTabSeen?.call();
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

  Future<void> _approve(WarmupContestationCore item) async {
    setState(() => _actionError = null);
    try {
      await WarmupContestationAdminCore.ensureSheets(item);
      await WarmupContestationAdminCore.approve(item.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('«${item.title}» approvata e condivisa.')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _actionError = e.toString().replaceFirst('StateError: ', '');
      });
    }
  }

  Future<void> _reject(WarmupContestationCore item) async {
    final noteCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rifiuta contestazione'),
        content: TextField(
          controller: noteCtrl,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Motivo (opzionale)',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Rifiuta'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _actionError = null);
    try {
      await WarmupContestationAdminCore.reject(
        id: item.id,
        note: noteCtrl.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('«${item.title}» rifiutata.')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _actionError = e.toString().replaceFirst('StateError: ', '');
      });
    } finally {
      noteCtrl.dispose();
    }
  }

  Future<void> _delete(WarmupContestationCore item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Elimina contestazione'),
        content: Text(
          'Vuoi eliminare definitivamente «${item.title}»?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Elimina'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _actionError = null);
    try {
      await WarmupContestationAdminCore.delete(item.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('«${item.title}» eliminata.')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _actionError = e.toString().replaceFirst('StateError: ', '');
      });
    }
  }

  Future<void> _openUserForm({WarmupContestationCore? existing}) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(
            title: Text(
              existing == null
                  ? 'Nuova contestazione'
                  : 'Modifica contestazione',
            ),
          ),
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: WarmupContestationAdminFormBody(existing: existing),
          ),
        ),
      ),
    );
    if (saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            existing == null
                ? 'Contestazione creata con schede AI.'
                : 'Contestazione aggiornata con schede AI.',
          ),
        ),
      );
    }
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
            'Come in CreditCalc: telefonata, contestazioni nel sollecito e nel '
            'recupero. Nella scheda Utenti approvi le contestazioni inviate dagli '
            'utenti per la community.',
            style: TextStyle(color: Colors.grey.shade700, height: 1.45),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: StreamBuilder<List<WarmupContestationCore>>(
            stream: WarmupContestationAdminCore.watchPendingReview(),
            builder: (context, pendingSnap) {
              final pendingCount = pendingSnap.data?.length ?? 0;
              return TabBar(
                controller: _tabs,
                isScrollable: true,
                tabs: [
                  const Tab(text: 'Telefonata'),
                  const Tab(text: 'Contestazioni nel sollecito'),
                  const Tab(text: 'Contestazioni nel recupero'),
                  Tab(
                    child: Badge(
                      isLabelVisible: pendingCount > 0,
                      label: Text('$pendingCount'),
                      child: const Text('Utenti'),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
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
              _BuiltinContestazioniTab(
                contestationContext: 'sollecito',
                itemIds: _sortedItemIds,
                payloadFor: _itemPayload,
                onChanged: _updateItem,
                onAdd: _addItem,
                onRemove: _removeItem,
                onEditUser: _openUserForm,
                onDeleteUser: _delete,
              ),
              _BuiltinContestazioniTab(
                contestationContext: 'recupero',
                itemIds: _sortedItemIds,
                payloadFor: _itemPayload,
                onChanged: _updateItem,
                onAdd: _addItem,
                onRemove: _removeItem,
                onEditUser: _openUserForm,
                onDeleteUser: _delete,
              ),
              _UserModerationTab(
                actionError: _actionError,
                onApprove: _approve,
                onReject: _reject,
                onDelete: _delete,
                onEdit: _openUserForm,
                onCreate: () => _openUserForm(),
              ),
            ],
            ),
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
        if (_selectedTab < 3)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
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
      padding: const EdgeInsets.symmetric(vertical: 16),
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

class _BuiltinContestazioniTab extends StatelessWidget {
  const _BuiltinContestazioniTab({
    required this.contestationContext,
    required this.itemIds,
    required this.payloadFor,
    required this.onChanged,
    required this.onAdd,
    required this.onRemove,
    required this.onEditUser,
    required this.onDeleteUser,
  });

  final String contestationContext;
  final List<String> itemIds;
  final Map<String, dynamic> Function(String) payloadFor;
  final void Function(String, Map<String, dynamic>) onChanged;
  final void Function({required String contestationContext}) onAdd;
  final void Function(String) onRemove;
  final Future<void> Function({WarmupContestationCore? existing}) onEditUser;
  final Future<void> Function(WarmupContestationCore item) onDeleteUser;

  List<String> get _filteredIds {
    return itemIds.where((id) {
      final context =
          (payloadFor(id)['context'] ?? 'sollecito').toString();
      return context == contestationContext;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filteredIds = _filteredIds;
    final contextLabel =
        contestationContext == 'recupero' ? 'recupero' : 'sollecito';

    return StreamBuilder<List<WarmupContestationCore>>(
      stream: WarmupContestationAdminCore.watchApprovedByContext(
        contestationContext,
      ),
      builder: (context, userSnap) {
        if (userSnap.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Errore lettura contestazioni utente: ${userSnap.error}',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.red.shade700),
              ),
            ),
          );
        }

        final userApproved = userSnap.data ?? const [];
        final waitingUserItems =
            userSnap.connectionState == ConnectionState.waiting &&
                !userSnap.hasData;

        return ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(vertical: 16),
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.tonalIcon(
                onPressed: () => onAdd(contestationContext: contestationContext),
                icon: const Icon(Icons.add),
                label: const Text('Nuova contestazione'),
              ),
            ),
            const SizedBox(height: 8),
            if (filteredIds.isEmpty && userApproved.isEmpty && !waitingUserItems)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  'Nessuna contestazione per il $contextLabel.',
                  style: TextStyle(color: Colors.grey.shade700),
                ),
              ),
            for (final id in filteredIds)
              _ContestationEditorCard(
                itemId: id,
                payload: payloadFor(id),
                onChanged: (patch) => onChanged(id, patch),
                onRemove: () => onRemove(id),
              ),
            if (waitingUserItems && userApproved.isEmpty) ...[
              const SizedBox(height: 12),
              const Center(child: CircularProgressIndicator()),
            ] else if (userApproved.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text(
                'Inserite dagli utenti e condivise',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Colors.grey.shade800,
                ),
              ),
              const SizedBox(height: 8),
              for (final item in userApproved)
                _ApprovedUserContestationCard(
                  item: item,
                  onEdit: () => onEditUser(existing: item),
                  onDelete: () => onDeleteUser(item),
                ),
            ],
          ],
        );
      },
    );
  }
}

class _ApprovedUserContestationCard extends StatelessWidget {
  const _ApprovedUserContestationCard({
    required this.item,
    required this.onEdit,
    required this.onDelete,
  });

  final WarmupContestationCore item;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final author = item.authorName?.trim().isNotEmpty == true
        ? item.authorName!.trim()
        : 'Utente';
    final insertedAt = _formatWarmupContestationDate(item.createdAt);
    final approvedAt = item.reviewedAt != null
        ? ' · Condivisa il ${_formatWarmupContestationDate(item.reviewedAt)}'
        : '';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: Colors.blue.shade50,
      child: ExpansionTile(
        leading: Icon(Icons.person_outline, color: Colors.blue.shade700),
        title: Text(
          item.title,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          'Inserita da $author il $insertedAt$approvedAt',
          style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Chip(
                      label: const Text('Inserita da utente'),
                      visualDensity: VisualDensity.compact,
                      backgroundColor: Colors.blue.shade100,
                    ),
                    Chip(
                      label: Text(item.category.label),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _approvedSheet('Dichiarata', item.declared),
                _approvedSheet('Significato', item.meaning),
                _approvedSheet('Rischio', item.risk),
                _approvedSheet('Obiettivo', item.objective),
                _approvedSheet('Risposta', item.response),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: onEdit,
                        child: const Text('Modifica'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: onDelete,
                        child: const Text('Elimina'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _approvedSheet(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
          ),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(height: 1.4, fontSize: 14)),
        ],
      ),
    );
  }
}

class _UserModerationTab extends StatelessWidget {
  const _UserModerationTab({
    required this.actionError,
    required this.onApprove,
    required this.onReject,
    required this.onDelete,
    required this.onEdit,
    required this.onCreate,
  });

  final String? actionError;
  final Future<void> Function(WarmupContestationCore item) onApprove;
  final Future<void> Function(WarmupContestationCore item) onReject;
  final Future<void> Function(WarmupContestationCore item) onDelete;
  final Future<void> Function({WarmupContestationCore? existing}) onEdit;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<WarmupContestationCore>>(
      stream: WarmupContestationAdminCore.watchPendingReview(),
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Errore lettura contestazioni: ${snap.error}',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.red.shade700),
              ),
            ),
          );
        }

        if (snap.connectionState == ConnectionState.waiting &&
            !snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final items = snap.data ?? const [];

        return ListView(
          padding: const EdgeInsets.symmetric(vertical: 16),
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: onCreate,
                icon: const Icon(Icons.add),
                label: const Text('Nuova contestazione'),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Approva le contestazioni inviate dagli utenti per '
              'renderle visibili a tutta la community nel warm-up.',
              style: TextStyle(
                fontSize: 15,
                color: Colors.grey.shade700,
                height: 1.45,
              ),
            ),
            if (actionError != null) ...[
              const SizedBox(height: 12),
              Text(
                actionError!,
                style: TextStyle(color: Colors.red.shade700),
              ),
            ],
            const SizedBox(height: 20),
            if (items.isEmpty)
              Card(
                child: const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Nessuna contestazione in attesa di valutazione.',
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            else
              ...items.map(
                (item) => _PendingCard(
                  item: item,
                  onApprove: () => onApprove(item),
                  onReject: () => onReject(item),
                  onEdit: () => onEdit(existing: item),
                  onDelete: () => onDelete(item),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _PendingCard extends StatelessWidget {
  const _PendingCard({
    required this.item,
    required this.onApprove,
    required this.onReject,
    required this.onEdit,
    required this.onDelete,
  });

  final WarmupContestationCore item;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final cardTheme = Theme.of(context).cardTheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: cardTheme.color,
      elevation: cardTheme.elevation ?? 0,
      shadowColor: cardTheme.shadowColor,
      shape: cardTheme.shape,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    item.title,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Chip(
                  label: Text(item.context.label),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${item.category.label} · ${item.authorName ?? item.authorUid}',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
            const SizedBox(height: 12),
            _sheet('Dichiarata', item.declared),
            _sheet('Significato', item.meaning),
            _sheet('Rischio', item.risk),
            _sheet('Obiettivo', item.objective),
            _sheet('Risposta', item.response),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onEdit,
                    child: const Text('Modifica'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: onDelete,
                    child: const Text('Elimina'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onReject,
                    child: const Text('Rifiuta'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: onApprove,
                    child: const Text('Approva'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _sheet(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
          ),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(height: 1.4, fontSize: 14)),
        ],
      ),
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
    final cardTheme = Theme.of(context).cardTheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: cardTheme.color,
      elevation: cardTheme.elevation ?? 0,
      shadowColor: cardTheme.shadowColor,
      shape: cardTheme.shape,
      clipBehavior: Clip.none,
      child: ExpansionTile(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text('Chiave: $phaseKey'),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
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
    final cardTheme = Theme.of(context).cardTheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: cardTheme.color,
      elevation: cardTheme.elevation ?? 0,
      shadowColor: cardTheme.shadowColor,
      shape: cardTheme.shape,
      clipBehavior: Clip.none,
      child: ExpansionTile(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text('ID: $itemId · ${payload['context']}'),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
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
        labelStyle: const TextStyle(
          color: Color(0xFF475569),
          fontWeight: FontWeight.w600,
        ),
        floatingLabelStyle: const TextStyle(
          color: Color(0xFF0F4C81),
          fontWeight: FontWeight.w600,
        ),
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
        labelStyle: const TextStyle(
          color: Color(0xFF475569),
          fontWeight: FontWeight.w600,
        ),
        floatingLabelStyle: const TextStyle(
          color: Color(0xFF0F4C81),
          fontWeight: FontWeight.w600,
        ),
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

String _formatWarmupContestationDate(DateTime? date) {
  if (date == null) return 'data non disponibile';
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  final hour = date.hour.toString().padLeft(2, '0');
  final minute = date.minute.toString().padLeft(2, '0');
  return '$day/$month/${date.year} $hour:$minute';
}
