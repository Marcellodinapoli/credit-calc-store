import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'commission_entry_data_access.dart';
import '../core/euro_format.dart';
import '../core/theme/app_card_theme.dart';
import '../core/theme/app_form_fields.dart';
import '../layout/credit_calc_page_host.dart';
import '../nav/credit_calc_nav.dart';

import 'commission_collections_shared.dart';
import 'commission_payment_resolver.dart';
import 'commission_settings_page.dart';

class _EntrySnapshot {
  final DateTime collectionDate;
  final String companyName;
  final double amountCollected;
  final double incentiveAmount;
  final String creditorId;
  final String paymentMethodKey;

  const _EntrySnapshot({
    required this.collectionDate,
    required this.companyName,
    required this.amountCollected,
    required this.incentiveAmount,
    required this.creditorId,
    required this.paymentMethodKey,
  });

  factory _EntrySnapshot.fromState(_CommissionEntryPageState state) {
    return _EntrySnapshot(
      collectionDate: DateTime(
        state._collectionDate.year,
        state._collectionDate.month,
        state._collectionDate.day,
      ),
      companyName: state._companyCtrl.text.trim(),
      amountCollected: state._amountCollected ?? 0,
      incentiveAmount: state._incentiveAmount ?? 0,
      creditorId: state._creditorId ?? '',
      paymentMethodKey: state._selectedPayment?.key ?? '',
    );
  }

  bool matches(_CommissionEntryPageState state) {
    final other = _EntrySnapshot.fromState(state);
    return collectionDate == other.collectionDate &&
        companyName == other.companyName &&
        _moneyEqual(amountCollected, other.amountCollected) &&
        _moneyEqual(incentiveAmount, other.incentiveAmount) &&
        creditorId == other.creditorId &&
        paymentMethodKey == other.paymentMethodKey;
  }

  static bool _moneyEqual(double a, double b) =>
      (a * 100).round() == (b * 100).round();
}

class CommissionEntryPage extends StatefulWidget {
  final String? entryId;

  const CommissionEntryPage({super.key, this.entryId});

  bool get isEditing => entryId != null && entryId!.isNotEmpty;

  @override
  State<CommissionEntryPage> createState() => _CommissionEntryPageState();
}

class _CommissionEntryPageState extends State<CommissionEntryPage> {
  final _companyCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _incentiveCtrl = TextEditingController();

  DateTime _collectionDate = DateTime.now();
  String? _creditorId;
  String? _creditorName;
  List<CommissionPaymentOption> _paymentOptions = [];
  CommissionPaymentOption? _selectedPayment;
  bool _loadingCreditor = false;
  bool _loadingEntry = false;
  bool _saving = false;
  _EntrySnapshot? _initialSnapshot;

  bool get _isEditing => widget.isEditing;

  bool get _hasChanges =>
      !_isEditing ||
      _initialSnapshot == null ||
      !_initialSnapshot!.matches(this);

  bool get _showSaveButton => !_isEditing || _hasChanges;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _loadEntry();
    }
  }

  static const _primaryBlue = Color(0xFF0A66C2);

  @override
  void dispose() {
    _companyCtrl.dispose();
    _amountCtrl.dispose();
    _incentiveCtrl.dispose();
    super.dispose();
  }

  double? get _amountCollected => EuroFormat.parse(_amountCtrl.text);

  double? get _incentiveAmount {
    final value = EuroFormat.parse(_incentiveCtrl.text);
    if (value == null) return 0;
    return value;
  }

  double? get _commissionAmount {
    final amount = _amountCollected;
    final rate = _selectedPayment?.rate;
    if (amount == null || rate == null) return null;
    return amount * rate / 100;
  }

  double? get _totalCommissionAmount {
    final base = _commissionAmount;
    if (base == null) return null;
    final incentive = _incentiveAmount ?? 0;
    return base + (incentive != 0 ? incentive : 0);
  }

  bool get _canSubmit =>
      _companyCtrl.text.trim().isNotEmpty &&
      (_amountCollected ?? 0) > 0 &&
      _creditorId != null &&
      _selectedPayment != null;

  String _formatDate(DateTime date) {
    final d = date.day.toString().padLeft(2, '0');
    final m = date.month.toString().padLeft(2, '0');
    return '$d/$m/${date.year}';
  }

  String _formatEuro(double? value) =>
      EuroFormat.formatNullable(value) ?? '—';

  String _formatPercent(double? value) {
    if (value == null) return '—';
    final text = value.toStringAsFixed(
      value.truncateToDouble() == value ? 0 : 2,
    ).replaceAll('.', ',');
    return '$text%';
  }

  Future<void> _loadEntry() async {
    setState(() => _loadingEntry = true);
    try {
      final data = await CommissionEntryDataAccess.instance
          .loadEntry(widget.entryId!);

      if (data == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Incasso non trovato.')),
        );
        Navigator.of(context).pop();
        return;
      }

      final date = CommissionCollectionsHelper.entryDate(data);
      if (date != null) _collectionDate = date;

      _companyCtrl.text = CommissionCollectionsHelper.companyName(data);
      _amountCtrl.text =
          EuroFormat.formatNum(data['amountCollected'] as num?);
      final incentive = data['incentiveAmount'];
      if (incentive is num && incentive != 0) {
        _incentiveCtrl.text = EuroFormat.formatNum(incentive);
      }

      final creditorId = (data['creditorId'] ?? '').toString();
      final creditorName = (data['creditorName'] ?? '').toString();
      if (creditorId.isNotEmpty) {
        await _loadCreditor(creditorId, creditorName, silent: true);
        final paymentKey = (data['paymentMethodKey'] ?? '').toString();
        for (final option in _paymentOptions) {
          if (option.key == paymentKey) {
            _selectedPayment = option;
            break;
          }
        }
      }

      _initialSnapshot = _EntrySnapshot.fromState(this);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Errore nel caricamento dell\'incasso.')),
      );
    } finally {
      if (mounted) setState(() => _loadingEntry = false);
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _collectionDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _collectionDate = picked);
    }
  }

  Future<void> _pickCreditor() async {
    final picked = await CommissionCreditorPicker.pickCreditor(
      context,
      tileSubtitle: 'Inserimento provvigione',
    );
    if (picked == null || !mounted) return;
    await _loadCreditor(picked.id, picked.name);
  }

  Future<void> _loadCreditor(
    String id,
    String name, {
    bool silent = false,
  }) async {
    setState(() {
      _loadingCreditor = true;
      _creditorId = id;
      _creditorName = name;
      _paymentOptions = [];
      _selectedPayment = null;
    });

    try {
      final data =
          await CommissionEntryDataAccess.instance.loadCreditorData(id) ?? {};
      final options = CommissionPaymentResolver.entryOptions(data);

      if (!mounted) return;

      setState(() {
        _paymentOptions = options;
        _selectedPayment = options.length == 1 ? options.first : null;
      });

      if (options.isEmpty && !silent) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Nessuna aliquota provvigionale configurata per questo creditore. '
              'Impostale da Imposta provvigioni.',
            ),
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Errore nel caricamento del creditore.')),
      );
    } finally {
      if (mounted) setState(() => _loadingCreditor = false);
    }
  }

  void _reset() {
    setState(() {
      _collectionDate = DateTime.now();
      _companyCtrl.clear();
      _amountCtrl.clear();
      _incentiveCtrl.clear();
      _creditorId = null;
      _creditorName = null;
      _paymentOptions = [];
      _selectedPayment = null;
    });
  }

  Future<void> _submit() async {
    if (!_canSubmit) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Compila tutti i campi obbligatori prima di inserire.'),
        ),
      );
      return;
    }

    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sessione scaduta. Effettua di nuovo l\'accesso.'),
        ),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final amount = _amountCollected!;
      final commission = _commissionAmount!;
      final incentive = _incentiveAmount ?? 0;
      final totalCommission = commission + (incentive != 0 ? incentive : 0);
      final payment = _selectedPayment!;
      final payload = <String, dynamic>{
        'userId': userId,
        'type': 'commission_entry',
        'collectionDate': Timestamp.fromDate(_collectionDate),
        'companyName': _companyCtrl.text.trim(),
        'amountCollected': amount,
        'creditorId': _creditorId,
        'creditorName': _creditorName,
        'paymentMethodKey': payment.key,
        'paymentMethodLabel': payment.label,
        'commissionRate': payment.rate,
        'commissionAmount': commission,
        'incentiveAmount': incentive,
        'totalCommissionAmount': totalCommission,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await CommissionEntryDataAccess.instance.saveEntry(
        payload: payload,
        entryId: _isEditing ? widget.entryId : null,
      );

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Errore durante il salvataggio.')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _requiredLabel(String text) {
    return RichText(
      text: TextSpan(
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
        children: [
          TextSpan(text: text),
          const TextSpan(
            text: ' *',
            style: TextStyle(color: Colors.orange),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader({
    required String title,
    required IconData icon,
    Widget? trailing,
  }) {
    return Row(
      children: [
        Icon(icon, color: _primaryBlue, size: 22),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        if (trailing != null) trailing,
      ],
    );
  }

  Widget _formCard() {
    return Card(
      color: AppCardTheme.surface,
      shape: AppCardTheme.shape,
      elevation: AppCardTheme.elevation,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _sectionHeader(
              title: _isEditing ? 'Modifica incasso' : 'Inserimento provvigioni',
              icon: Icons.edit_note_outlined,
              trailing: OutlinedButton.icon(
                onPressed: _isEditing ? null : _reset,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Resetta'),
              ),
            ),
            const SizedBox(height: 20),
            _requiredLabel('Data dell\'incasso'),
            const SizedBox(height: 8),
            InkWell(
              onTap: _pickDate,
              borderRadius: BorderRadius.circular(4),
              child: InputDecorator(
                decoration: appFormFieldDecoration('Seleziona data'),
                child: Row(
                  children: [
                    Expanded(child: Text(_formatDate(_collectionDate))),
                    Icon(Icons.calendar_today_outlined,
                        size: 20, color: Colors.grey.shade600),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            _requiredLabel('Ragione sociale'),
            const SizedBox(height: 8),
            appFormTextField(
              label: 'Nome committente / debitore',
              controller: _companyCtrl,
              padding: EdgeInsets.zero,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 10),
            Text(
              'Per un incasso massivo non riferito a singoli clienti, scrivi '
              '«Massivo» nel campo nominativo e indica l\'importo totale incassato.',
              style: TextStyle(
                fontSize: 12,
                height: 1.45,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 16),
            _requiredLabel('Importo incassato'),
            const SizedBox(height: 8),
            appFormTextField(
              label: 'Importo in euro',
              controller: _amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              padding: EdgeInsets.zero,
              onChanged: (_) => setState(() {}),
              onEditingComplete: () {
                EuroFormat.applyToController(_amountCtrl);
                setState(() {});
              },
            ),
            const SizedBox(height: 16),
            Text(
              'Incentivo',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
            ),
            const SizedBox(height: 8),
            appFormTextField(
              label: 'Importo incentivo in euro (opzionale)',
              controller: _incentiveCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              padding: EdgeInsets.zero,
              onChanged: (_) => setState(() {}),
              onEditingComplete: () {
                EuroFormat.applyToController(_incentiveCtrl);
                setState(() {});
              },
            ),
            const SizedBox(height: 16),
            _requiredLabel('Creditore'),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _loadingCreditor ? null : _pickCreditor,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                alignment: Alignment.centerLeft,
              ),
              icon: _loadingCreditor
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      _creditorName == null
                          ? Icons.account_balance_outlined
                          : Icons.check_circle_outline,
                      color: _creditorName == null
                          ? _primaryBlue
                          : Colors.green.shade700,
                    ),
              label: Text(
                _creditorName ?? 'Seleziona creditore',
                style: TextStyle(
                  fontWeight:
                      _creditorName == null ? FontWeight.w500 : FontWeight.w600,
                ),
              ),
            ),
            if (_paymentOptions.isNotEmpty) ...[
              const SizedBox(height: 16),
              _requiredLabel('Modalità di incasso'),
              const SizedBox(height: 8),
              DropdownButtonFormField<CommissionPaymentOption>(
                value: _selectedPayment,
                decoration: appFormFieldDecoration('Seleziona modalità'),
                items: _paymentOptions
                    .map(
                      (option) => DropdownMenuItem(
                        value: option,
                        child: Text(
                          '${option.label} (${_formatPercent(option.rate)})',
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setState(() => _selectedPayment = value),
              ),
            ],
            const SizedBox(height: 16),
            Text(
              '* Campi obbligatori',
              style: TextStyle(
                fontSize: 12,
                color: Colors.orange.shade800,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryRow(String label, String value, {bool highlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 160,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: highlight ? FontWeight.w700 : FontWeight.w600,
                color: highlight ? _primaryBlue : Colors.black87,
                fontSize: highlight ? 16 : 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryCard() {
    return Card(
      shape: AppCardTheme.shape,
      elevation: AppCardTheme.elevation,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _sectionHeader(
              title: 'Riepilogo',
              icon: Icons.summarize_outlined,
            ),
            const SizedBox(height: 8),
            const Divider(),
            _summaryRow('Creditore', _creditorName ?? '—'),
            _summaryRow('Ragione sociale',
                _companyCtrl.text.trim().isEmpty ? '—' : _companyCtrl.text.trim()),
            _summaryRow(
              'Importo incassato',
              _formatEuro(_amountCollected),
            ),
            _summaryRow(
              'Modalità di incasso',
              _selectedPayment?.label ?? '—',
            ),
            _summaryRow(
              'Provvigione',
              _formatPercent(_selectedPayment?.rate),
            ),
            _summaryRow(
              'Importo provvigioni',
              _formatEuro(_commissionAmount),
            ),
            _summaryRow(
              'Incentivo',
              (_incentiveAmount ?? 0) != 0
                  ? _formatEuro(_incentiveAmount)
                  : '—',
            ),
            _summaryRow(
              'Totale provvigioni',
              _formatEuro(_totalCommissionAmount),
              highlight: true,
            ),
            _summaryRow('Data dell\'incasso', _formatDate(_collectionDate)),
            if (_showSaveButton) ...[
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _saving || !_canSubmit ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.green.shade700,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.check),
                label: Text(
                  _saving
                      ? (_isEditing ? 'Salvataggio...' : 'Inserimento...')
                      : (_isEditing ? 'Salva modifiche' : 'Inserisci'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingEntry) {
      return wrapCreditCalcPage(
      secondary: true,
      pageTitle: _isEditing ? 'Modifica incasso' : 'Inserisci provvigioni',
        current: CreditCalcNavItem.commissions,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return wrapCreditCalcPage(
      secondary: true,
      pageTitle: _isEditing ? 'Modifica incasso' : 'Inserisci provvigioni',
      current: CreditCalcNavItem.commissions,
      body: ColoredBox(
        color: const Color(0xFFE8E8E8),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 960;

            final columns = Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _formCard()),
                const SizedBox(width: 16),
                Expanded(child: _summaryCard()),
              ],
            );

            if (wide) {
              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
                child: columns,
              );
            }

            return ListView(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
              children: [
                _formCard(),
                const SizedBox(height: 16),
                _summaryCard(),
              ],
            );
          },
        ),
      ),
    );
  }
}
