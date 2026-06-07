import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../core/euro_format.dart';
import '../core/firestore_user_scope.dart';
import '../core/theme/app_form_fields.dart';
import '../layout/credit_calc_page_host.dart';
import '../nav/credit_calc_nav.dart';

import 'commission_collections_shared.dart';

class CreditorDetailPage extends StatefulWidget {
  final String creditorId;
  final String name;
  final String notes;
  final int maxAge;

  const CreditorDetailPage({
    super.key,
    required this.creditorId,
    required this.name,
    this.notes = '',
    this.maxAge = 80,
  });

  @override
  State<CreditorDetailPage> createState() => _CreditorDetailPageState();
}

class _PdrRowControllers {
  _PdrRowControllers({
    String from = '',
    String to = '',
    String installments = '',
    this.fromLocked = false,
  })  : fromCtrl = TextEditingController(text: from),
        toCtrl = TextEditingController(text: to),
        installmentsCtrl = TextEditingController(text: installments);

  final TextEditingController fromCtrl;
  final TextEditingController toCtrl;
  final TextEditingController installmentsCtrl;
  final bool fromLocked;

  void dispose() {
    fromCtrl.dispose();
    toCtrl.dispose();
    installmentsCtrl.dispose();
  }

  Map<String, dynamic> toMap() => {
        'from': EuroFormat.storageDigits(fromCtrl.text),
        'to': EuroFormat.storageDigits(toCtrl.text),
        'installments': installmentsCtrl.text.trim(),
      };

  static _PdrRowControllers fromMap(
    Map<String, dynamic> data, {
    bool fromLocked = false,
  }) {
    return _PdrRowControllers(
      from: EuroFormat.formatNum(num.tryParse((data['from'] ?? '').toString())),
      to: EuroFormat.formatNum(num.tryParse((data['to'] ?? '').toString())),
      installments: (data['installments'] ?? '').toString(),
      fromLocked: fromLocked,
    );
  }
}

class _CreditorDetailPageState extends State<CreditorDetailPage> {
  final _displayLabelCtrl = TextEditingController();
  final _clientNameCtrl = TextEditingController();
  final _bbHeaderCtrl = TextEditingController();
  final _ibanCtrl = TextEditingController();
  final _voHeaderCtrl = TextEditingController();
  final _indVoCtrl = TextEditingController();
  final _bpHeaderCtrl = TextEditingController();
  final _ccpCtrl = TextEditingController();
  final _indBpCtrl = TextEditingController();
  final _assHeaderCtrl = TextEditingController();
  final _minInstallmentCtrl = TextEditingController();
  final _maxAgePdrCtrl = TextEditingController();

  final List<_PdrRowControllers> _pdrRows = [_PdrRowControllers()];

  bool _effettiCambiari = false;
  bool _bollettiniPostali = false;
  bool _contanti = true;
  bool _pdrConfiguredOnLoad = false;
  bool _loading = true;
  bool _saving = false;
  bool _deleting = false;
  bool _isExistingCreditor = false;
  String? _initialFormSnapshotJson;

  static const _fieldSpacing = 12.0;
  static const _sectionSpacing = 16.0;

  void _applyEuroSuffix(TextEditingController controller) {
    EuroFormat.applyToController(controller);
  }

  bool _isPdrRowComplete(_PdrRowControllers row) {
    return EuroFormat.parseInt(row.fromCtrl.text) != null &&
        EuroFormat.parseInt(row.toCtrl.text) != null &&
        row.installmentsCtrl.text.trim().isNotEmpty;
  }

  bool _isPdrRowStarted(_PdrRowControllers row) {
    return row.fromCtrl.text.trim().isNotEmpty ||
        row.toCtrl.text.trim().isNotEmpty ||
        row.installmentsCtrl.text.trim().isNotEmpty;
  }

  bool get _isFirstPdrRowStarted {
    if (_pdrRows.isEmpty) return false;
    return _isPdrRowStarted(_pdrRows.first);
  }

  /// Rateizzo obbligatorio solo se la prima fascia PDR è stata avviata.
  bool get _isPaymentMethodsMandatory => _isFirstPdrRowStarted;

  bool get _pdrExtrasMandatory =>
      _pdrConfiguredOnLoad || _isFirstPdrRowStarted;

  void _touchForm() => setState(() {});

  Map<String, dynamic> _buildFormSnapshot() {
    return {
      'clientName': _clientNameCtrl.text.trim(),
      'displayLabel': _displayLabelCtrl.text.trim(),
      'bbHeader': _bbHeaderCtrl.text.trim(),
      'iban': _ibanCtrl.text.trim(),
      'voHeader': _voHeaderCtrl.text.trim(),
      'indVo': _indVoCtrl.text.trim(),
      'bpHeader': _bpHeaderCtrl.text.trim(),
      'ccp': _ccpCtrl.text.trim(),
      'indBp': _indBpCtrl.text.trim(),
      'assHeader': _assHeaderCtrl.text.trim(),
      'minInstallmentAmount': EuroFormat.storageDigits(_minInstallmentCtrl.text),
      'maxAgePdr': _maxAgePdrCtrl.text.trim(),
      'effettiCambiari': _effettiCambiari,
      'bollettiniPostali': _bollettiniPostali,
      'contanti': _contanti,
      'pdrBands': _pdrRows.map((r) => r.toMap()).toList(),
    };
  }

  void _captureFormSnapshot() {
    _initialFormSnapshotJson = jsonEncode(_buildFormSnapshot());
  }

  bool get _hasFormChanges {
    if (!_isExistingCreditor || _initialFormSnapshotJson == null) return true;
    return jsonEncode(_buildFormSnapshot()) != _initialFormSnapshotJson;
  }

  bool get _showSaveButton => !_isExistingCreditor || _hasFormChanges;

  void _syncNextRowFrom(int index) {
    if (index >= _pdrRows.length - 1) return;
    final maxVal = EuroFormat.parseInt(_pdrRows[index].toCtrl.text);
    if (maxVal == null) return;
    _pdrRows[index + 1].fromCtrl.text =
        EuroFormat.format((maxVal + 1).toDouble());
  }

  @override
  void initState() {
    super.initState();
    _displayLabelCtrl.text = widget.name;
    _maxAgePdrCtrl.text = widget.maxAge.toString();
    _loadData();
  }

  @override
  void dispose() {
    _displayLabelCtrl.dispose();
    _clientNameCtrl.dispose();
    _bbHeaderCtrl.dispose();
    _ibanCtrl.dispose();
    _voHeaderCtrl.dispose();
    _indVoCtrl.dispose();
    _bpHeaderCtrl.dispose();
    _ccpCtrl.dispose();
    _indBpCtrl.dispose();
    _assHeaderCtrl.dispose();
    _minInstallmentCtrl.dispose();
    _maxAgePdrCtrl.dispose();
    for (final row in _pdrRows) {
      row.dispose();
    }
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('creditors')
          .doc(widget.creditorId)
          .get();

      if (!doc.exists) {
        if (mounted) {
          setState(() {
            _isExistingCreditor = false;
            _loading = false;
          });
        }
        return;
      }

      _isExistingCreditor = true;
      final data = doc.data() ?? {};
      final payments =
          (data['paymentCoordinates'] as Map<String, dynamic>?) ?? {};
      final methods =
          (data['paymentMethods'] as Map<String, dynamic>?) ?? {};
      final bands = data['pdrBands'];

      _displayLabelCtrl.text =
          (data['displayLabel'] ?? widget.name).toString();
      _clientNameCtrl.text = (data['clientName'] ?? data['name'] ?? '').toString();
      _bbHeaderCtrl.text = (payments['bbHeader'] ?? '').toString();
      _ibanCtrl.text = (payments['iban'] ?? '').toString();
      _voHeaderCtrl.text = (payments['voHeader'] ?? '').toString();
      _indVoCtrl.text = (payments['indVo'] ?? '').toString();
      _bpHeaderCtrl.text = (payments['bpHeader'] ?? '').toString();
      _ccpCtrl.text = (payments['ccp'] ?? '').toString();
      _indBpCtrl.text = (payments['indBp'] ?? '').toString();
      _assHeaderCtrl.text = (payments['assHeader'] ?? '').toString();
      _minInstallmentCtrl.text = EuroFormat.formatNum(
        num.tryParse((data['minInstallmentAmount'] ?? '').toString()),
      );
      _maxAgePdrCtrl.text =
          (data['maxAgePdr'] ?? data['maxAge'] ?? widget.maxAge).toString();

      _effettiCambiari = methods['effettiCambiari'] == true;
      _bollettiniPostali = methods['bollettiniPostali'] == true;
      _contanti = true;

      for (final row in _pdrRows) {
        row.dispose();
      }
      _pdrRows.clear();

      if (bands is List && bands.isNotEmpty) {
        _pdrConfiguredOnLoad = true;
        for (var i = 0; i < bands.length; i++) {
          final item = bands[i];
          if (item is Map<String, dynamic>) {
            _pdrRows.add(
              _PdrRowControllers.fromMap(item, fromLocked: i > 0),
            );
          }
        }
      } else {
        _pdrConfiguredOnLoad = false;
      }
      if (_pdrRows.isEmpty) {
        _pdrRows.add(_PdrRowControllers());
      } else {
        for (var i = 0; i < _pdrRows.length - 1; i++) {
          _syncNextRowFrom(i);
        }
      }

      _captureFormSnapshot();
    } catch (_) {
      // Mantieni i valori di default se il caricamento fallisce.
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _addPdrRow() {
    final last = _pdrRows.last;
    if (!_isPdrRowComplete(last)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Compila tutti i campi della fascia PDR corrente prima di aggiungerne un\'altra.',
          ),
        ),
      );
      return;
    }

    final maxVal = EuroFormat.parseInt(last.toCtrl.text);
    if (maxVal == null) return;

    setState(() {
      _pdrRows.add(
        _PdrRowControllers(
          from: EuroFormat.format((maxVal + 1).toDouble()),
          fromLocked: true,
        ),
      );
    });
    _touchForm();
  }

  void _removePdrRow(int index) {
    if (index <= 0 || _pdrRows.length <= 1) return;
    setState(() {
      _pdrRows[index].dispose();
      _pdrRows.removeAt(index);
    });
    _touchForm();
  }

  bool get _isFormValid => _validateFormMessage() == null;

  String? _validateFormMessage() {
    if (_clientNameCtrl.text.trim().isEmpty) {
      return 'Compila il nome della committente.';
    }

    for (var i = 0; i < _pdrRows.length; i++) {
      final row = _pdrRows[i];
      if (!_isPdrRowStarted(row)) continue;
      if (!_isPdrRowComplete(row)) {
        return i == 0
            ? 'Compila tutti i campi della prima fascia PDR.'
            : 'Compila tutti i campi della fascia PDR ${i + 1}.';
      }
      final from = EuroFormat.parseInt(row.fromCtrl.text);
      final to = EuroFormat.parseInt(row.toCtrl.text);
      if (from != null && to != null && from > to) {
        return 'Nella fascia PDR ${i + 1} il valore minimo non può superare il massimo.';
      }
    }

    if (_pdrExtrasMandatory &&
        EuroFormat.parseInt(_minInstallmentCtrl.text) == null) {
      return 'Compila l\'importo minimo della rata/effetto.';
    }

    if (_isPaymentMethodsMandatory && !_effettiCambiari && !_bollettiniPostali) {
      return 'Se compili la prima fascia PDR, seleziona almeno Effetti cambiari o '
          'Bollettini postali.';
    }

    return null;
  }

  void _cancelToCreditorsList() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  void _resetForm() {
    setState(() {
      _clientNameCtrl.clear();
      _bbHeaderCtrl.clear();
      _ibanCtrl.clear();
      _voHeaderCtrl.clear();
      _indVoCtrl.clear();
      _bpHeaderCtrl.clear();
      _ccpCtrl.clear();
      _indBpCtrl.clear();
      _assHeaderCtrl.clear();
      _minInstallmentCtrl.clear();
      _maxAgePdrCtrl.text = widget.maxAge.toString();
      _effettiCambiari = false;
      _bollettiniPostali = false;
      _contanti = true;
      _pdrConfiguredOnLoad = false;

      for (final row in _pdrRows) {
        row.dispose();
      }
      _pdrRows
        ..clear()
        ..add(_PdrRowControllers());
    });
  }

  Future<void> _save() async {
    final validationError = _validateFormMessage();
    if (validationError != null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(validationError)),
      );
      return;
    }

    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sessione scaduta. Effettua di nuovo l\'accesso.')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final maxAgePdr = int.tryParse(_maxAgePdrCtrl.text.trim());
      final ref = FirebaseFirestore.instance
          .collection('creditors')
          .doc(widget.creditorId);
      final existing = await ref.get();

      final data = <String, dynamic>{
        'displayLabel': _displayLabelCtrl.text.trim(),
        'clientName': _clientNameCtrl.text.trim(),
        'name': _clientNameCtrl.text.trim().isNotEmpty
            ? _clientNameCtrl.text.trim()
            : _displayLabelCtrl.text.trim(),
        'maxAge': maxAgePdr ?? widget.maxAge,
        'maxAgePdr': maxAgePdr ?? widget.maxAge,
        'minInstallmentAmount': EuroFormat.storageDigits(_minInstallmentCtrl.text),
        'paymentCoordinates': {
          'bbHeader': _bbHeaderCtrl.text.trim(),
          'iban': _ibanCtrl.text.trim(),
          'voHeader': _voHeaderCtrl.text.trim(),
          'indVo': _indVoCtrl.text.trim(),
          'bpHeader': _bpHeaderCtrl.text.trim(),
          'ccp': _ccpCtrl.text.trim(),
          'indBp': _indBpCtrl.text.trim(),
          'assHeader': _assHeaderCtrl.text.trim(),
        },
        'pdrBands': [
          for (final row in _pdrRows)
            if (_isPdrRowStarted(row)) row.toMap(),
        ],
        'paymentMethods': {
          'contanti': true,
          'effettiCambiari': _effettiCambiari,
          'bollettiniPostali': _bollettiniPostali,
        },
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (!existing.exists) {
        data['createdAt'] = FieldValue.serverTimestamp();
      }
      data['userId'] = userId;

      await ref.set(data, SetOptions(merge: true));

      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop(true);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Errore durante il salvataggio.')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _deleteCreditor() async {
    try {
      final snapshot = await FirestoreUserScope.userCalculations().get();
      final linked = CommissionCollectionsHelper.countLinkedIncassi(
        CommissionCollectionsHelper.commissionDocs(snapshot),
        widget.creditorId,
      );

      if (!mounted) return;

      if (linked > 0) {
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Impossibile eliminare il creditore'),
            content: Text(
              'Sono presenti $linked '
              '${linked == 1 ? 'incasso collegato' : 'incassi collegati'}.\n\n'
              'Elimina prima gli incassi da Provvigioni → Vedi elenco pratiche, '
              'poi potrai cancellare il creditore.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Ho capito'),
              ),
            ],
          ),
        );
        return;
      }

      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Elimina creditore'),
          content: const Text(
            'Confermi l\'eliminazione definitiva di questo creditore?',
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

      if (confirm != true || !mounted) return;

      setState(() => _deleting = true);
      await FirebaseFirestore.instance
          .collection('creditors')
          .doc(widget.creditorId)
          .delete();

      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop('deleted');
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Errore durante l\'eliminazione.')),
      );
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  Widget _sectionHeading(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: _sectionSpacing),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Colors.black87,
        ),
      ),
    );
  }

  Widget _fieldRow(List<Widget> fields) {
    return Padding(
      padding: const EdgeInsets.only(bottom: _fieldSpacing),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < fields.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            Expanded(child: fields[i]),
          ],
        ],
      ),
    );
  }

  Widget _inlineField({
    required String label,
    required TextEditingController controller,
    TextInputType? keyboardType,
    bool readOnly = false,
    ValueChanged<String>? onChanged,
    VoidCallback? onEditingComplete,
  }) {
    return TextField(
      controller: controller,
      readOnly: readOnly,
      keyboardType: keyboardType,
      onChanged: onChanged,
      onEditingComplete: onEditingComplete,
      style: readOnly ? TextStyle(color: Colors.grey.shade800) : null,
      decoration: appFormFieldDecoration(label).copyWith(
        filled: readOnly,
        fillColor: readOnly ? Colors.grey.shade100 : null,
      ),
    );
  }

  Widget _spacedField(Widget child) {
    return Padding(
      padding: const EdgeInsets.only(bottom: _fieldSpacing),
      child: child,
    );
  }

  Widget _buildActionButtons() {
    final busy = _saving || _deleting;
    const primaryBlue = Color(0xFF0A66C2);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: busy ? null : _cancelToCreditorsList,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.black87,
                  side: BorderSide(color: Colors.grey.shade400),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                icon: const Icon(Icons.arrow_back, size: 20),
                label: const Text('Annulla'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: busy ? null : _resetForm,
                style: OutlinedButton.styleFrom(
                  foregroundColor: primaryBlue,
                  side: const BorderSide(color: primaryBlue),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                icon: const Icon(Icons.refresh, size: 20),
                label: const Text('Reset'),
              ),
            ),
            if (_showSaveButton) ...[
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  onPressed: busy || !_isFormValid ? null : _save,
                  style: FilledButton.styleFrom(
                    backgroundColor: primaryBlue,
                    disabledBackgroundColor: Colors.grey.shade300,
                    disabledForegroundColor: Colors.grey.shade600,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
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
                      : const Icon(Icons.save_outlined, size: 20),
                  label: Text(
                    _saving
                        ? 'Salvataggio...'
                        : (_isExistingCreditor ? 'Salva modifiche' : 'Salva'),
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: busy ? null : _deleteCreditor,
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.red.shade700,
            side: BorderSide(color: Colors.red.shade300),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          icon: _deleting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.delete_outline, size: 20),
          label: Text(_deleting ? 'Eliminazione...' : 'Cancella creditore'),
        ),
      ],
    );
  }

  Widget _pdrSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeading('Dati per il pdr come da scheda lavoro'),
        ...List.generate(_pdrRows.length, (index) {
          final row = _pdrRows[index];
          final isFirst = index == 0;
          final fromLocked = !isFirst || row.fromLocked;
          return Padding(
            padding: const EdgeInsets.only(bottom: _fieldSpacing),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _fieldRow([
                    _inlineField(
                      label: 'Da valore min.',
                      controller: row.fromCtrl,
                      keyboardType: TextInputType.number,
                      readOnly: fromLocked,
                      onEditingComplete: fromLocked
                          ? null
                          : () => _applyEuroSuffix(row.fromCtrl),
                      onChanged: fromLocked
                          ? null
                          : (_) => setState(() {}),
                    ),
                    _inlineField(
                      label: 'A valore max.',
                      controller: row.toCtrl,
                      keyboardType: TextInputType.number,
                      onEditingComplete: () {
                        _applyEuroSuffix(row.toCtrl);
                        _syncNextRowFrom(index);
                        _touchForm();
                      },
                      onChanged: (_) => _touchForm(),
                    ),
                    _inlineField(
                      label: 'Rate previste',
                      controller: row.installmentsCtrl,
                      keyboardType: TextInputType.number,
                      onChanged: (_) => _touchForm(),
                    ),
                  ]),
                ),
                if (!isFirst) ...[
                  const SizedBox(width: 4),
                  IconButton(
                    onPressed: () => _removePdrRow(index),
                    icon: const Icon(Icons.remove_circle_outline),
                    color: Colors.red.shade700,
                    tooltip: 'Rimuovi fascia',
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ],
            ),
          );
        }),
        const SizedBox(height: _fieldSpacing),
        Align(
          alignment: Alignment.centerLeft,
          child: IconButton.filled(
            onPressed: _isPdrRowComplete(_pdrRows.last) ? _addPdrRow : null,
            icon: const Icon(Icons.add),
            tooltip: 'Aggiungi fascia PDR',
            style: IconButton.styleFrom(
              backgroundColor: const Color(0xFF0A66C2),
              foregroundColor: Colors.white,
              disabledBackgroundColor: Colors.grey.shade400,
              disabledForegroundColor: Colors.white70,
            ),
          ),
        ),
        const SizedBox(height: _sectionSpacing + 8),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return wrapCreditCalcPage(
      secondary: true,
      pageTitle: 'Impostazioni creditori',
      current: CreditCalcNavItem.creditors,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
              children: [
                _sectionHeading('*Nome della committente'),
                _fieldRow([
                  _inlineField(
                    label: 'Identificativo',
                    controller: _displayLabelCtrl,
                    readOnly: true,
                  ),
                  _inlineField(
                    label: 'Nome committente',
                    controller: _clientNameCtrl,
                    onChanged: (_) => _touchForm(),
                  ),
                ]),
                const SizedBox(height: _sectionSpacing),
                _sectionHeading('Coordinate dei pagamenti previsti'),
                _fieldRow([
                  _inlineField(
                    label: 'Bonifico bancario / intestazione',
                    controller: _bbHeaderCtrl,
                    onChanged: (_) => _touchForm(),
                  ),
                  _inlineField(
                    label: 'Iban',
                    controller: _ibanCtrl,
                    onChanged: (_) => _touchForm(),
                  ),
                ]),
                _fieldRow([
                  _inlineField(
                    label: 'Vaglia ordinario / intestazione',
                    controller: _voHeaderCtrl,
                    onChanged: (_) => _touchForm(),
                  ),
                  _inlineField(
                    label: 'Vaglia ordinario / indirizzo',
                    controller: _indVoCtrl,
                    onChanged: (_) => _touchForm(),
                  ),
                ]),
                _fieldRow([
                  _inlineField(
                    label: 'Bollettino postale / intestazione',
                    controller: _bpHeaderCtrl,
                    onChanged: (_) => _touchForm(),
                  ),
                  _inlineField(
                    label: 'Ccp',
                    controller: _ccpCtrl,
                    onChanged: (_) => _touchForm(),
                  ),
                ]),
                _spacedField(
                  appFormTextField(
                    label: 'Bollettino postale / indirizzo',
                    controller: _indBpCtrl,
                    padding: EdgeInsets.zero,
                    onChanged: (_) => _touchForm(),
                  ),
                ),
                _spacedField(
                  appFormTextField(
                    label: 'Assegno / intestazione',
                    controller: _assHeaderCtrl,
                    padding: EdgeInsets.zero,
                    onChanged: (_) => _touchForm(),
                  ),
                ),
                _pdrSection(),
                _spacedField(
                  _inlineField(
                    label: 'Importo minimo rata/effetto',
                    controller: _minInstallmentCtrl,
                    keyboardType: TextInputType.number,
                    onEditingComplete: () {
                      _applyEuroSuffix(_minInstallmentCtrl);
                      _touchForm();
                    },
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                _spacedField(
                  _inlineField(
                    label: 'Età massima PDR',
                    controller: _maxAgePdrCtrl,
                    keyboardType: TextInputType.number,
                    onChanged: (_) => _touchForm(),
                  ),
                ),
                const SizedBox(height: _sectionSpacing),
                _sectionHeading(
                  _isPaymentMethodsMandatory
                      ? '*Modalità di pagamento per il rateizzo'
                      : 'Modalità di pagamento per il rateizzo',
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Contanti'),
                  value: true,
                  onChanged: null,
                  controlAffinity: ListTileControlAffinity.leading,
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Effetti cambiari'),
                  value: _effettiCambiari,
                  onChanged: (v) {
                    _effettiCambiari = v ?? false;
                    _touchForm();
                  },
                  controlAffinity: ListTileControlAffinity.leading,
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Bollettini postali'),
                  value: _bollettiniPostali,
                  onChanged: (v) {
                    _bollettiniPostali = v ?? false;
                    _touchForm();
                  },
                  controlAffinity: ListTileControlAffinity.leading,
                ),
                const SizedBox(height: 20),
                _buildActionButtons(),
              ],
            ),
    );
  }
}
