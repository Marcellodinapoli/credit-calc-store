import 'package:flutter/material.dart';

import '../../auth/registration_coupon_service.dart';
import '../../auth/registration_plan_selection_result.dart';
import '../../core/admin/bk_admin_service.dart';
import '../../core/admin/coupon_admin_service.dart';
import '../area/personal_area_shell.dart';

/// Backoffice — creazione e gestione coupon registrazione.
class BkCouponsPage extends StatefulWidget {
  const BkCouponsPage({super.key});

  @override
  State<BkCouponsPage> createState() => _BkCouponsPageState();
}

class _BkCouponsPageState extends State<BkCouponsPage> {
  bool _checkingAdmin = true;
  bool _isAdmin = false;

  final _codeCtrl = TextEditingController();
  final _labelCtrl = TextEditingController();
  final _maxUsesCtrl = TextEditingController();
  DateTime? _expiresAt;
  String? _restrictedPlan;
  bool _saving = false;
  String? _formError;

  @override
  void initState() {
    super.initState();
    _loadAdmin();
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    _labelCtrl.dispose();
    _maxUsesCtrl.dispose();
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

  Future<void> _pickExpiry() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _expiresAt ?? now.add(const Duration(days: 365)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 3650)),
      helpText: 'Scadenza coupon (opzionale)',
    );
    if (date == null || !mounted) return;
    setState(() => _expiresAt = date);
  }

  Future<void> _createCoupon() async {
    final code = _codeCtrl.text.trim();
    if (code.isEmpty) {
      setState(() => _formError = 'Inserisci il codice coupon.');
      return;
    }

    int? maxUses;
    final maxRaw = _maxUsesCtrl.text.trim();
    if (maxRaw.isNotEmpty) {
      maxUses = int.tryParse(maxRaw);
      if (maxUses == null || maxUses < 1) {
        setState(() => _formError = 'Utilizzi massimi non valido.');
        return;
      }
    }

    setState(() {
      _saving = true;
      _formError = null;
    });

    try {
      await CouponAdminService.createCoupon(
        code: code,
        label: _labelCtrl.text.trim(),
        maxUses: maxUses,
        expiresAt: _expiresAt,
        restrictedPlan: _restrictedPlan,
      );
      if (!mounted) return;
      _codeCtrl.clear();
      _labelCtrl.clear();
      _maxUsesCtrl.clear();
      setState(() {
        _expiresAt = null;
        _restrictedPlan = null;
        _saving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Coupon ${RegistrationCouponService.normalizeCode(code)} creato.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _formError = e
            .toString()
            .replaceFirst('StateError: ', '')
            .replaceFirst('ArgumentError: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PersonalAreaShell(
      pageTitle: 'Coupon registrazione',
      bypassMaintenance: true,
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
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'I coupon creati qui possono essere inseriti dagli utenti '
                        'nel form di registrazione. Con accesso gratuito per sempre '
                        'attivano il piano scelto senza abbonamento.',
                        style: TextStyle(
                          fontSize: 15,
                          color: Colors.grey.shade700,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 20),
                      _buildCreateCard(),
                      const SizedBox(height: 28),
                      const Text(
                        'Coupon esistenti',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildList(),
                    ],
                  ),
                ),
    );
  }

  Widget _buildCreateCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Nuovo coupon',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _codeCtrl,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'Codice coupon *',
                hintText: 'Es. PROMO2026',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _labelCtrl,
              decoration: const InputDecoration(
                labelText: 'Nota interna (opzionale)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _maxUsesCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Utilizzi massimi (vuoto = illimitati)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String?>(
              value: _restrictedPlan,
              decoration: const InputDecoration(
                labelText: 'Piano vincolato (vuoto = tutti i piani)',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: null, child: Text('Qualsiasi piano')),
                DropdownMenuItem(value: 'free', child: Text('Solo Gratis')),
                DropdownMenuItem(value: 'plus', child: Text('Solo Plus')),
                DropdownMenuItem(
                  value: 'enterprise',
                  child: Text('Solo Enterprise'),
                ),
              ],
              onChanged: (v) => setState(() => _restrictedPlan = v),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickExpiry,
                    icon: const Icon(Icons.event_outlined, size: 18),
                    label: Text(
                      _expiresAt == null
                          ? 'Scadenza (opzionale)'
                          : 'Scade: ${_formatDate(_expiresAt!)}',
                    ),
                  ),
                ),
                if (_expiresAt != null) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: 'Rimuovi scadenza',
                    onPressed: () => setState(() => _expiresAt = null),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ],
            ),
            if (_formError != null) ...[
              const SizedBox(height: 10),
              Text(
                _formError!,
                style: TextStyle(color: Colors.red.shade700, fontSize: 13),
              ),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _saving ? null : _createCoupon,
              child: _saving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Crea coupon'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList() {
    return StreamBuilder<List<CouponRecord>>(
      stream: CouponAdminService.watchCoupons(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (snap.hasError) {
          return Text(
            'Errore caricamento: ${snap.error}',
            style: TextStyle(color: Colors.red.shade700),
          );
        }
        final items = snap.data ?? [];
        if (items.isEmpty) {
          return Text(
            'Nessun coupon ancora creato.',
            style: TextStyle(color: Colors.grey.shade600),
          );
        }
        return Column(
          children: [
            for (final c in items) ...[
              _CouponTile(
                record: c,
                onToggle: (enabled) => CouponAdminService.setEnabled(
                  code: c.code,
                  enabled: enabled,
                ),
              ),
              const SizedBox(height: 10),
            ],
          ],
        );
      },
    );
  }

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

class _CouponTile extends StatelessWidget {
  final CouponRecord record;
  final ValueChanged<bool> onToggle;

  const _CouponTile({required this.record, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final status = !record.enabled
        ? 'Disattivato'
        : record.expired
            ? 'Scaduto'
            : record.exhausted
                ? 'Esaurito'
                : 'Attivo';

    final statusColor = status == 'Attivo'
        ? const Color(0xFF1B5E20)
        : Colors.grey.shade700;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    record.code,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                Switch(value: record.enabled, onChanged: onToggle),
              ],
            ),
            Text(
              status,
              style: TextStyle(color: statusColor, fontWeight: FontWeight.w600),
            ),
            if (record.label != null) Text('Nota: ${record.label}'),
            Text(
              'Utilizzi: ${record.usedCount}'
              '${record.maxUses != null ? ' / ${record.maxUses}' : ' (illimitati)'}',
            ),
            if (record.plan != null)
              Text('Piano: ${registrationPlanLabel(record.plan)}'),
            if (record.expiresAt != null)
              Text('Scadenza: ${_fmt(record.expiresAt!)}'),
            if (record.lifetimeFree) const Text('Accesso gratuito per sempre'),
          ],
        ),
      ),
    );
  }

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}
