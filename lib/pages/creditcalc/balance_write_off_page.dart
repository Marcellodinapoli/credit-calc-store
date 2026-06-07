import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:credit_calc_core/credit_calc_core.dart'
    hide
        BalanceWriteOffPage,
        CommissionInstallmentPayment,
        PlanCancelWithCommissionsAction,
        RepaymentPlanCommissionExportRequest,
        RepaymentPlanCommissionExportResult,
        RepaymentPlanCommissionExporter,
        showPlanCancelWithCommissionsDialog;
import 'package:flutter/material.dart';

import '../../core/adaptive_button_styles.dart';
import '../../ui/layout/adaptive_action_bar.dart';
import 'repayment_plan_commission_export.dart';
import 'repayment_plan_session_storage.dart';

class _CreditorOption {
  final String id;
  final String name;

  const _CreditorOption({required this.id, required this.name});
}

class _InstallmentLine {
  final DateTime date;
  final double amount;

  const _InstallmentLine({required this.date, required this.amount});
}

enum _AmountEditSource { debito, percent, stralciato, residuo }

class BalanceWriteOffPage extends StatefulWidget {
  const BalanceWriteOffPage({super.key});

  @override
  State<BalanceWriteOffPage> createState() => _BalanceWriteOffPageState();
}

class _BalanceWriteOffPageState extends State<BalanceWriteOffPage> {
  static const _primaryBlue = Color(0xFF0A66C2);

  String? _creditorId;
  List<_CreditorOption>? _creditorOptions;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _creditorsSub;

  final _debitoCtrl = TextEditingController();
  final _percentCtrl = TextEditingController();
  final _stralciatoCtrl = TextEditingController();
  final _residuoCtrl = TextEditingController();

  int _installmentCount = 1;
  DateTime _firstPaymentDate = DateTime.now();
  String? _paymentMethodKey;
  List<CommissionPaymentOption> _paymentOptions = [];

  bool _syncing = false;
  bool _isResetting = false;
  bool _calcolato = false;
  bool _exporting = false;
  bool _showValidationErrors = false;
  final List<String> _sessionCommissionDocIds = [];
  List<_InstallmentLine> _installments = const [];
  String? _calcError;

  final _scrollController = ScrollController();
  final _resultsKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _sessionCommissionDocIds.addAll(RepaymentPlanSessionStorage.readIds());
    _creditorsSub =
        FirestoreUserScope.creditorsOrdered().snapshots().listen((snap) {
      if (!mounted) return;
      final docs = FirestoreUserScope.sortCreditorsByCreatedAt(snap.docs);
      final options = docs
          .map((doc) {
            final name = (doc.data()['name'] ?? 'Senza nome').toString().trim();
            return _CreditorOption(
              id: doc.id,
              name: name.isEmpty ? 'Senza nome' : name,
            );
          })
          .toList();
      setState(() {
        _creditorOptions = options;
        if (_creditorId != null &&
            !options.any((o) => o.id == _creditorId)) {
          _creditorId = null;
          _paymentOptions = [];
          _paymentMethodKey = null;
        }
      });
    });
  }

  @override
  void dispose() {
    _creditorsSub?.cancel();
    _scrollController.dispose();
    _debitoCtrl.dispose();
    _percentCtrl.dispose();
    _stralciatoCtrl.dispose();
    _residuoCtrl.dispose();
    super.dispose();
  }

  void _resetCalcolo() {
    if (!_calcolato) return;
    setState(() {
      _calcolato = false;
      _installments = const [];
      _calcError = null;
    });
  }

  void _touchForm() {
    _resetCalcolo();
    setState(() {});
  }

  double? get _debito => EuroFormat.parse(_debitoCtrl.text);

  String? get _creditorName {
    final id = _creditorId;
    if (id == null) return null;
    return _creditorOptions
        ?.where((c) => c.id == id)
        .map((c) => c.name)
        .firstOrNull;
  }

  void _syncFrom(_AmountEditSource source) {
    if (_syncing || _isResetting) return;
    _syncing = true;
    try {
      final debito = _debito;
      if (debito == null || debito <= 0) return;

      switch (source) {
        case _AmountEditSource.debito:
          final pct = _parsePercent(_percentCtrl.text);
          if (pct != null) {
            _applyStralciatoResiduo(debito, pct);
          } else {
            final str = EuroFormat.parse(_stralciatoCtrl.text);
            if (str != null) {
              _applyFromStralciato(debito, str);
            } else {
              final res = EuroFormat.parse(_residuoCtrl.text);
              if (res != null) _applyFromResiduo(debito, res);
            }
          }
        case _AmountEditSource.percent:
          final pct = _parsePercent(_percentCtrl.text);
          if (pct == null) return;
          _applyStralciatoResiduo(debito, pct.clamp(0, 100));
        case _AmountEditSource.stralciato:
          final str = EuroFormat.parse(_stralciatoCtrl.text);
          if (str == null) return;
          _applyFromStralciato(debito, str.clamp(0, debito));
        case _AmountEditSource.residuo:
          final res = EuroFormat.parse(_residuoCtrl.text);
          if (res == null) return;
          _applyFromResiduo(debito, res.clamp(0, debito));
      }
    } finally {
      _syncing = false;
    }
  }

  double? _parsePercent(String text) {
    var s = text.trim().replaceAll('%', '').trim();
    if (s.isEmpty) return null;
    s = s.replaceAll(',', '.');
    return double.tryParse(s);
  }

  void _setPercent(double value) {
    _percentCtrl.text =
        '${value.toStringAsFixed(2).replaceAll('.', ',')} %';
  }

  void _setEuro(TextEditingController controller, double value) {
    controller.text = EuroFormat.format(value);
  }

  void _applyStralciatoResiduo(double debito, double percent) {
    final stralciato = (debito * percent / 100 * 100).round() / 100;
    final residuo = ((debito - stralciato) * 100).round() / 100;
    _setEuro(_stralciatoCtrl, stralciato);
    _setEuro(_residuoCtrl, residuo);
    _setPercent(percent);
  }

  void _applyFromStralciato(double debito, double stralciato) {
    final residuo = ((debito - stralciato) * 100).round() / 100;
    final pct = debito > 0 ? (stralciato / debito * 100) : 0.0;
    _setEuro(_residuoCtrl, residuo);
    _setPercent(pct);
  }

  void _applyFromResiduo(double debito, double residuo) {
    final stralciato = ((debito - residuo) * 100).round() / 100;
    final pct = debito > 0 ? (stralciato / debito * 100) : 0.0;
    _setEuro(_stralciatoCtrl, stralciato);
    _setPercent(pct);
  }

  void _commitEuroField(
    TextEditingController controller,
    _AmountEditSource source,
  ) {
    EuroFormat.applyToController(controller);
    _syncFrom(source);
    _touchForm();
  }

  void _commitPercentField() {
    final pct = _parsePercent(_percentCtrl.text);
    if (pct != null) {
      _setPercent(pct.clamp(0, 100));
      _syncFrom(_AmountEditSource.percent);
    }
    _touchForm();
  }

  Future<void> _loadPaymentOptions(String creditorId) async {
    final doc = await FirebaseFirestore.instance
        .collection('creditors')
        .doc(creditorId)
        .get();
    if (!mounted) return;
    final options =
        CommissionPaymentResolver.entryOptions(doc.data() ?? {});
    setState(() {
      _paymentOptions = options;
      if (_paymentMethodKey != null &&
          !options.any((o) => o.key == _paymentMethodKey)) {
        _paymentMethodKey = null;
      }
      if (_paymentMethodKey == null && options.length == 1) {
        _paymentMethodKey = options.first.key;
      }
    });
  }

  Future<void> _pickFirstPaymentDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _firstPaymentDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      _firstPaymentDate = DateTime(picked.year, picked.month, picked.day);
      _resetCalcolo();
    });
  }

  void _syncSessionCommissionDocIds(Iterable<String> ids) {
    final unique = ids.where((id) => id.isNotEmpty).toSet();
    if (unique.isEmpty) return;
    _sessionCommissionDocIds
      ..clear()
      ..addAll(unique);
    RepaymentPlanSessionStorage.clear();
    RepaymentPlanSessionStorage.appendIds(_sessionCommissionDocIds);
  }

  void _resetForm() {
    _isResetting = true;
    setState(() {
      _creditorId = null;
      _paymentMethodKey = null;
      _paymentOptions = [];
      _installmentCount = 1;
      _firstPaymentDate = DateTime.now();
      _calcolato = false;
      _installments = const [];
      _sessionCommissionDocIds.clear();
      RepaymentPlanSessionStorage.clear();
      _calcError = null;
      _showValidationErrors = false;
      _debitoCtrl.clear();
      _percentCtrl.clear();
      _stralciatoCtrl.clear();
      _residuoCtrl.clear();
    });
    _isResetting = false;
  }

  bool get _canSviluppa {
    if (_creditorId == null) return false;
    final debito = _debito;
    final residuo = EuroFormat.parse(_residuoCtrl.text);
    if (debito == null || debito <= 0) return false;
    if (residuo == null || residuo <= 0) return false;
    if (_paymentMethodKey == null || _paymentOptions.isEmpty) return false;
    return true;
  }

  String? _validate() {
    if (_creditorId == null) return 'Seleziona un creditore.';
    final debito = _debito;
    if (debito == null || debito <= 0) {
      return 'Inserisci il debito totale.';
    }
    final residuo = EuroFormat.parse(_residuoCtrl.text);
    if (residuo == null || residuo <= 0) {
      return 'Inserisci il residuo da pagare.';
    }
    if (_paymentMethodKey == null) {
      return 'Seleziona la modalità di pagamento.';
    }
    if (_paymentOptions.isEmpty) {
      return 'Configura le aliquote provvigionali per il creditore.';
    }
    return null;
  }

  void _revealRequiredFieldErrors() {
    setState(() => _showValidationErrors = true);
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  String? _creditorFieldError() {
    if (!_showValidationErrors) return null;
    return requiredFieldError(_creditorId == null);
  }

  String? _debitoFieldError() {
    if (!_showValidationErrors) return null;
    final debito = _debito;
    return requiredFieldError(debito == null || debito <= 0);
  }

  String? _residuoFieldError() {
    if (!_showValidationErrors) return null;
    final residuo = EuroFormat.parse(_residuoCtrl.text);
    return requiredFieldError(residuo == null || residuo <= 0);
  }

  String? _paymentMethodFieldError() {
    if (!_showValidationErrors) return null;
    return requiredFieldError(
      _paymentMethodKey == null || _paymentOptions.isEmpty,
    );
  }

  List<double> _splitInstallmentAmounts(double total, int count) {
    final totalCents = (total * 100).round();
    if (count <= 1) return [totalCents / 100];
    final baseCents = totalCents ~/ count;
    final remainder = totalCents - baseCents * (count - 1);
    return [
      ...List<double>.filled(count - 1, baseCents / 100),
      remainder / 100,
    ];
  }

  void _sviluppa() {
    final error = _validate();
    if (error != null) {
      setState(() {
        _showValidationErrors = true;
        _calcError = error;
        _calcolato = false;
      });
      return;
    }

    final residuo = EuroFormat.parse(_residuoCtrl.text)!;
    final amounts = _splitInstallmentAmounts(residuo, _installmentCount);
    final lines = <_InstallmentLine>[];
    for (var i = 0; i < _installmentCount; i++) {
      lines.add(
        _InstallmentLine(
          date: addMonthsSameCalendarDay(_firstPaymentDate, i),
          amount: amounts[i],
        ),
      );
    }

    setState(() {
      _calcError = null;
      _showValidationErrors = false;
      _calcolato = true;
      _installments = lines;
    });
    _scrollToResults();
  }

  void _scrollToResults() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final target = _resultsKey.currentContext;
        if (target == null) return;
        Scrollable.ensureVisible(
          target,
          duration: const Duration(milliseconds: 450),
          curve: Curves.easeInOut,
          alignment: 0.08,
        );
      });
    });
  }

  Future<void> _aggiungiIncasso() async {
    if (!_calcolato || _creditorId == null || _paymentMethodKey == null) {
      return;
    }

    final creditorName = _creditorName;
    if (creditorName == null) return;

    final hasFuture = _installments.any(
      (line) => isPaymentAfterCurrentMonth(line.date),
    );

    final paymentLabel = CommissionPaymentResolver.labelForKey(
      _paymentMethodKey!,
    );

    final dialogResult = await showCommissionExportDialog(
      context: context,
      hasPaymentsAfterCurrentMonth: hasFuture,
      scheduledPayments: [
        for (var i = 0; i < _installments.length; i++)
          CommissionExportScheduleLine(
            date: _installments[i].date,
            amount: _installments[i].amount,
            label: 'Rata ${i + 1}',
          ),
      ],
      description:
          'Verranno registrati gli incassi per il saldo e stralcio '
          '($paymentLabel), importo residuo '
          '${EuroFormat.format(_installments.fold<double>(0, (s, i) => s + i.amount))}.',
    );

    if (dialogResult == null || !mounted) return;

    setState(() => _exporting = true);
    final result =
        await RepaymentPlanCommissionExporter.saveInstallmentCollections(
      creditorId: _creditorId!,
      creditorName: creditorName,
      companyName: dialogResult.companyName,
      paymentMethodKey: _paymentMethodKey!,
      dateMode: dialogResult.dateMode,
      singleCollectionDate: dialogResult.collectionDate,
      installments: [
        for (final line in _installments)
          CommissionInstallmentPayment(
            date: line.date,
            amount: line.amount,
          ),
      ],
    );
    if (!mounted) return;
    setState(() {
      _exporting = false;
      if (result.savedDocIds.isNotEmpty) {
        _sessionCommissionDocIds.addAll(result.savedDocIds);
        RepaymentPlanSessionStorage.appendIds(result.savedDocIds);
      }
    });

    if (result.savedCount > 0 && !result.hasErrors) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${result.savedCount} '
            '${result.savedCount == 1 ? 'incasso registrato' : 'incassi registrati'} '
            'in provvigioni.',
          ),
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.errors.isNotEmpty
              ? result.errors.join(' ')
              : 'Nessun incasso registrato.',
        ),
        duration: const Duration(seconds: 8),
      ),
    );
  }

  Future<bool> _deleteSessionCommissions() async {
    if (_sessionCommissionDocIds.isEmpty) return true;

    setState(() => _exporting = true);
    final deleteResult =
        await RepaymentPlanCommissionExporter.deleteRegisteredCollections(
      _sessionCommissionDocIds,
    );
    if (!mounted) return false;

    setState(() {
      _exporting = false;
      if (deleteResult.savedCount > 0) {
        _sessionCommissionDocIds.removeWhere(
          deleteResult.savedDocIds.contains,
        );
        if (_sessionCommissionDocIds.isEmpty) {
          RepaymentPlanSessionStorage.clear();
        } else {
          RepaymentPlanSessionStorage.clear();
          RepaymentPlanSessionStorage.appendIds(_sessionCommissionDocIds);
        }
      }
    });

    if (deleteResult.savedCount == 0 && deleteResult.hasErrors) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(deleteResult.errors.join(' '))),
      );
      return false;
    }

    if (deleteResult.savedCount > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            deleteResult.savedCount == 1
                ? 'Incasso eliminato.'
                : '${deleteResult.savedCount} incassi eliminati.',
          ),
        ),
      );
    }
    return true;
  }

  Future<void> _annullaPiano() async {
    _syncSessionCommissionDocIds([
      ..._sessionCommissionDocIds,
      ...RepaymentPlanSessionStorage.readIds(),
    ]);

    if (_sessionCommissionDocIds.isEmpty) {
      _exitPlanScreen();
      return;
    }

    final action = await showPlanCancelWithCommissionsDialog(
      context,
      registeredCount: _sessionCommissionDocIds.length,
    );
    if (!mounted) return;

    switch (action) {
      case null:
      case PlanCancelWithCommissionsAction.stay:
        return;
      case PlanCancelWithCommissionsAction.deleteAndStay:
        await _deleteSessionCommissions();
        return;
      case PlanCancelWithCommissionsAction.exitKeepCommissions:
        _exitPlanScreen();
        return;
      case PlanCancelWithCommissionsAction.exitDeleteCommissions:
        if (await _deleteSessionCommissions()) {
          _exitPlanScreen();
        }
        return;
    }
  }

  void _exitPlanScreen() {
    RepaymentPlanSessionStorage.clear();
    final navigator = Navigator.of(context, rootNavigator: true);
    if (navigator.canPop()) {
      navigator.pop();
      return;
    }
    _resetForm();
  }

  String _formatDate(DateTime date) => formatCommissionExportDate(date);

  String _labelEuro(double? value) =>
      value == null ? '—' : EuroFormat.format(value);

  String _labelPercent() {
    final pct = _parsePercent(_percentCtrl.text);
    if (pct == null) return '—';
    return '${pct.toStringAsFixed(2).replaceAll('.', ',')} %';
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

  Widget _summaryRow(String label, String value) {
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
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _euroField(
    String label,
    TextEditingController controller,
    _AmountEditSource source, {
    String? errorText,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Focus(
        onFocusChange: (hasFocus) {
          if (!hasFocus && !_isResetting) {
            _commitEuroField(controller, source);
          }
        },
        child: appAdaptiveEuroTextField(
          controller: controller,
          textInputAction: TextInputAction.next,
          onChanged: (_) => _touchForm(),
          onEditingComplete: () => _commitEuroField(controller, source),
          decoration: appFormFieldDecoration(label, errorText: errorText),
        ),
      ),
    );
  }

  Widget _percentField() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Focus(
        onFocusChange: (hasFocus) {
          if (!hasFocus && !_isResetting) _commitPercentField();
        },
        child: TextField(
          controller: _percentCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          textInputAction: TextInputAction.next,
          onChanged: (_) => _touchForm(),
          onEditingComplete: _commitPercentField,
          decoration: appFormFieldDecoration('Percentuale stralcio').copyWith(
            hintText: 'es. 25',
            suffixText: '%',
          ),
        ),
      ),
    );
  }

  Widget _installmentCountSelector() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Dilazioni sul residuo',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 1; i <= 10; i++)
                ChoiceChip(
                  label: Text('$i'),
                  selected: _installmentCount == i,
                  selectedColor: ProjectColors.calc.withValues(alpha: 0.2),
                  onSelected: (selected) {
                    if (!selected) return;
                    setState(() {
                      _installmentCount = i;
                      _resetCalcolo();
                    });
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _dateRow() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: _pickFirstPaymentDate,
        borderRadius: BorderRadius.circular(4),
        child: InputDecorator(
          decoration: appFormFieldDecoration(
            'Data prima rata (stesso giorno ogni mese)',
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_formatDate(_firstPaymentDate)),
              const Icon(
                Icons.calendar_today,
                size: 18,
                color: Colors.black54,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _formCard(List<_CreditorOption> options) {
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
              title: 'Saldo e stralcio',
              icon: Icons.balance_outlined,
              trailing: OutlinedButton.icon(
                onPressed: _resetForm,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Resetta'),
              ),
            ),
            const SizedBox(height: 20),
            if (options.isEmpty)
              Text(
                'Nessun creditore configurato. Aggiungine uno da '
                'Impostazioni creditori.',
                style: TextStyle(color: Colors.orange.shade800, fontSize: 14),
              )
            else
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: DropdownButtonFormField<String>(
                  value: _creditorId,
                  decoration: appFormFieldDecoration(
                    'Creditore',
                    errorText: _creditorFieldError(),
                  ),
                  items: [
                    for (final c in options)
                      DropdownMenuItem(value: c.id, child: Text(c.name)),
                  ],
                  onChanged: (id) {
                    if (id == null) return;
                    setState(() {
                      _creditorId = id;
                      _paymentMethodKey = null;
                      _resetCalcolo();
                    });
                    _loadPaymentOptions(id);
                  },
                ),
              ),
            _euroField(
              'Debito totale',
              _debitoCtrl,
              _AmountEditSource.debito,
              errorText: _debitoFieldError(),
            ),
            _percentField(),
            _euroField(
              'Importo da stralciare',
              _stralciatoCtrl,
              _AmountEditSource.stralciato,
            ),
            _euroField(
              'Residuo da pagare',
              _residuoCtrl,
              _AmountEditSource.residuo,
              errorText: _residuoFieldError(),
            ),
            const Divider(height: 28),
            _installmentCountSelector(),
            _dateRow(),
            if (_paymentOptions.isEmpty && _creditorId != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  'Nessuna modalità con aliquota provvigionale. '
                  'Configurale da Imposta provvigioni.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.orange.shade900,
                  ),
                ),
              )
            else if (_paymentOptions.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: DropdownButtonFormField<String>(
                  value: _paymentMethodKey,
                  decoration: appFormFieldDecoration(
                    'Modalità di pagamento',
                    errorText: _paymentMethodFieldError(),
                  ),
                  items: [
                    for (final o in _paymentOptions)
                      DropdownMenuItem(
                        value: o.key,
                        child: Text(o.label),
                      ),
                  ],
                  onChanged: (key) {
                    setState(() {
                      _paymentMethodKey = key;
                      _resetCalcolo();
                    });
                  },
                ),
              ),
            if (_calcError != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  _calcError!,
                  style: TextStyle(
                    color: Colors.red.shade700,
                    fontSize: 13,
                  ),
                ),
              ),
            const SizedBox(height: 8),
            Text(
              '* Compila i campi e usa il riepilogo per sviluppare il saldo',
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

  Widget _summaryCard() {
    final stralciato = EuroFormat.parse(_stralciatoCtrl.text);
    final residuo = EuroFormat.parse(_residuoCtrl.text);
    final paymentLabel = _paymentMethodKey == null
        ? '—'
        : CommissionPaymentResolver.labelForKey(_paymentMethodKey!);

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
            _summaryRow('Debito totale', _labelEuro(_debito)),
            _summaryRow('Percentuale stralcio', _labelPercent()),
            _summaryRow('Importo da stralciare', _labelEuro(stralciato)),
            _summaryRow('Residuo da pagare', _labelEuro(residuo)),
            _summaryRow('Dilazioni residuo', '$_installmentCount'),
            _summaryRow('Data prima rata', _formatDate(_firstPaymentDate)),
            _summaryRow('Modalità di pagamento', paymentLabel),
            if (_calcolato)
              KeyedSubtree(
                key: _resultsKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Divider(height: 24),
                    const Text(
                      'Piano sviluppato',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                    ),
                    const SizedBox(height: 8),
                    for (var i = 0; i < _installments.length; i++)
                      _summaryRow(
                        'Rata ${i + 1}',
                        '${_formatDate(_installments[i].date)} — '
                        '${EuroFormat.format(_installments[i].amount)}',
                      ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _exporting ? null : _aggiungiIncasso,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _primaryBlue,
                          side: const BorderSide(color: _primaryBlue),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        icon: _exporting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.payments_outlined),
                        label: Text(
                          _exporting
                              ? 'Registrazione incassi...'
                              : 'Aggiungi incasso',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _actionBar() {
    return AdaptiveActionBar(
      actions: [
        AdaptiveActionBarAction(
          flex: 1,
          child: OutlinedButton.icon(
            onPressed: _annullaPiano,
            style: AdaptiveButtonStyles.calcOutlinedDanger(),
            icon: const Icon(Icons.close),
            label: const Text('Annulla'),
          ),
        ),
        AdaptiveActionBarAction(
          flex: 2,
          child: FilledButton.icon(
            onPressed: _canSviluppa ? _sviluppa : _revealRequiredFieldErrors,
            style: AdaptiveButtonStyles.calcFilled(),
            icon: Icon(
              _calcolato ? Icons.check_circle_outline : Icons.play_arrow,
            ),
            label: Text(
              _calcolato ? 'Saldo sviluppato' : 'Sviluppa saldo',
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildScrollContent(List<_CreditorOption> options) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 960;
        if (wide) {
          return SingleChildScrollView(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _formCard(options)),
                const SizedBox(width: 16),
                Expanded(child: _summaryCard()),
              ],
            ),
          );
        }

        return ListView(
          controller: _scrollController,
          children: [
            _formCard(options),
            const SizedBox(height: 16),
            _summaryCard(),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final options = _creditorOptions;

    return wrapCreditCalcPage(
      secondary: true,
      pageTitle: 'Saldo e stralcio',
      current: CreditCalcNavItem.develop,
      bottomBar: options == null ? null : _actionBar(),
      body: options == null
          ? const Center(child: CircularProgressIndicator())
          : _buildScrollContent(options),
    );
  }
}
