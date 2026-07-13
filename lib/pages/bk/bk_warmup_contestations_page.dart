import 'package:flutter/material.dart';

import '../../core/admin/bk_admin_service.dart';
import '../../core/admin/warmup_contestation_admin_service.dart';
import '../../models/warmup_contestation.dart';
import '../../services/warmup_contestation_service.dart';
import '../area/personal_area_shell.dart';
import 'bk_warmup_contestation_form_page.dart';

/// Backoffice — moderazione contestazioni warm-up inviate dagli utenti.
class BkWarmupContestationsPage extends StatefulWidget {
  const BkWarmupContestationsPage({super.key});

  @override
  State<BkWarmupContestationsPage> createState() =>
      _BkWarmupContestationsPageState();
}

class _BkWarmupContestationsPageState extends State<BkWarmupContestationsPage> {
  bool _checkingAdmin = true;
  bool _isAdmin = false;
  String? _actionError;

  @override
  void initState() {
    super.initState();
    _loadAdmin();
  }

  Future<void> _loadAdmin() async {
    final ok = await BkAdminService.isAdmin(forceRefresh: true);
    if (!mounted) return;
    setState(() {
      _isAdmin = ok;
      _checkingAdmin = false;
    });
  }

  Future<void> _approve(WarmupContestation item) async {
    setState(() => _actionError = null);
    try {
      final ready = await WarmupContestationAdminService.ensureSheets(item);
      await WarmupContestationAdminService.approve(ready.id);
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

  Future<void> _reject(WarmupContestation item) async {
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
      await WarmupContestationAdminService.reject(
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

  Future<void> _delete(WarmupContestation item) async {
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
      await WarmupContestationAdminService.delete(item.id);
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

  Future<void> _openForm({WarmupContestation? existing}) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => BkWarmupContestationFormPage(existing: existing),
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
    return PersonalAreaShell(
      pageTitle: 'Contestazioni warm-up',
      showAccountMenu: false,
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
              : StreamBuilder<List<WarmupContestation>>(
                  stream: WarmupContestationService.watchPendingReview(),
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
                      padding: const EdgeInsets.fromLTRB(0, 0, 0, 24),
                      children: [
                        Align(
                          alignment: Alignment.centerRight,
                          child: FilledButton.icon(
                            onPressed: () => _openForm(),
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
                        if (_actionError != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            _actionError!,
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
                          ...items.map((item) => _PendingCard(
                                item: item,
                                onApprove: () => _approve(item),
                                onReject: () => _reject(item),
                                onEdit: () => _openForm(existing: item),
                                onDelete: () => _delete(item),
                              )),
                      ],
                    );
                  },
                ),
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

  final WarmupContestation item;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
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
