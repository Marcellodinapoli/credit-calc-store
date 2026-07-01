import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/maintenance_service.dart';
import '../../models/call_analysis_practice_data.dart';
import '../../services/call_analysis_config_service.dart';
import '../../services/call_analysis_service.dart';
import '../../ui/layout/page_shell.dart';
import '../../widgets/maintenance_section_gate.dart';

/// Strumenti — analisi telefonata e suggerimento leve negoziali.
class PhoneCallAnalysisPage extends StatefulWidget {
  const PhoneCallAnalysisPage({super.key});

  @override
  State<PhoneCallAnalysisPage> createState() => _PhoneCallAnalysisPageState();
}

class _PhoneCallAnalysisPageState extends State<PhoneCallAnalysisPage> {
  final _formKey = GlobalKey<FormState>();

  final _creditorCtrl = TextEditingController();
  final _installmentCtrl = TextEditingController();
  final _paidInstallmentsCtrl = TextEditingController();
  final _totalInstallmentsCtrl = TextEditingController();
  final _remainingDebtCtrl = TextEditingController();
  final _defaultFeesCtrl = TextEditingController();
  final _ageCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  String _creditType = CallAnalysisPracticeData.creditTypes.first;
  int _unpaidInstallments = 1;
  DateTime? _lastPaymentDate;
  String _employmentStatus = CallAnalysisPracticeData.employmentStatuses.first;
  bool _hasCoObligor = false;
  bool _hasGuarantor = false;
  bool _lastPromiseKept = false;

  bool _loading = false;
  String? _error;
  String? _analysisResult;

  @override
  void dispose() {
    _creditorCtrl.dispose();
    _installmentCtrl.dispose();
    _paidInstallmentsCtrl.dispose();
    _totalInstallmentsCtrl.dispose();
    _remainingDebtCtrl.dispose();
    _defaultFeesCtrl.dispose();
    _ageCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickLastPaymentDate() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _lastPaymentDate ?? now,
      firstDate: DateTime(now.year - 30),
      lastDate: now,
      helpText: 'Data ultimo pagamento',
    );
    if (date != null) setState(() => _lastPaymentDate = date);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_lastPaymentDate == null) {
      setState(() => _error = 'Seleziona la data dell\'ultimo pagamento.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _analysisResult = null;
    });

    try {
      final practice = CallAnalysisPracticeData(
        creditor: _creditorCtrl.text.trim(),
        creditType: _creditType,
        installmentAmount: _installmentCtrl.text.trim(),
        unpaidInstallments: _unpaidInstallments,
        paidInstallments: _paidInstallmentsCtrl.text.trim(),
        totalInstallments: _totalInstallmentsCtrl.text.trim(),
        remainingDebt: _remainingDebtCtrl.text.trim(),
        defaultFees: _defaultFeesCtrl.text.trim(),
        lastPaymentDate: _lastPaymentDate!,
        debtorAge: int.parse(_ageCtrl.text.trim()),
        employmentStatus: _employmentStatus,
        hasCoObligor: _hasCoObligor,
        hasGuarantor: _hasGuarantor,
        lastPromiseKept: _lastPromiseKept,
        consultantNotes: _notesCtrl.text.trim(),
      );

      final prompt = await CallAnalysisConfigService.loadPrompt();
      final analysis = await CallAnalysisService.analyze(
        practice: practice,
        systemPrompt: prompt,
      );

      if (!mounted) return;
      setState(() {
        _analysisResult = analysis;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Impossibile ottenere l\'analisi. Riprova tra poco.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SecondaryPageScaffold(
      pageTitle: 'Analisi telefonata',
      project: BrandedPageProject.calc,
      body: MaintenanceSectionGate(
        sectionName: MaintenanceService.creditCalc,
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
            Text(
              'Inserisci i dati della pratica (senza nome e cognome del debitore). '
              'L\'assistente suggerirà le leve da utilizzare in telefonata.',
              style: TextStyle(color: Colors.grey.shade700, height: 1.45),
            ),
            const SizedBox(height: 8),
            Text(
              'Le risposte hanno scopo operativo e non sostituiscono il giudizio '
              'del consulente.',
              style: TextStyle(
                color: Colors.orange.shade800,
                fontSize: 13,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            _sectionTitle('Pratica'),
            _textField(_creditorCtrl, 'Creditore'),
            _dropdown(
              label: 'Tipologia credito',
              value: _creditType,
              items: CallAnalysisPracticeData.creditTypes,
              onChanged: (v) => setState(() => _creditType = v!),
            ),
            _textField(
              _installmentCtrl,
              'Importo rata',
              hint: 'Es. 150,00 €',
              keyboard: TextInputType.text,
            ),
            _dropdownInt(
              label: 'Numero rate insolute',
              value: _unpaidInstallments,
              items: const [1, 2, 3, 4],
              onChanged: (v) => setState(() => _unpaidInstallments = v!),
            ),
            _textField(
              _paidInstallmentsCtrl,
              'Numero rate pagate',
              keyboard: TextInputType.number,
              digitsOnly: true,
            ),
            _textField(
              _totalInstallmentsCtrl,
              'Numero rate totali',
              keyboard: TextInputType.number,
              digitsOnly: true,
            ),
            _textField(
              _remainingDebtCtrl,
              'Debito residuo',
              hint: 'Es. 1.200,00 €',
            ),
            _textField(
              _defaultFeesCtrl,
              'Morosità/spese',
              hint: 'Es. 45,00 €',
            ),
            _dateField(),
            const SizedBox(height: 8),
            _sectionTitle('Debitore'),
            _textField(
              _ageCtrl,
              'Età',
              keyboard: TextInputType.number,
              digitsOnly: true,
              validator: (v) {
                final n = int.tryParse((v ?? '').trim());
                if (n == null || n < 18 || n > 110) {
                  return 'Età non valida';
                }
                return null;
              },
            ),
            _dropdown(
              label: 'Stato occupazionale',
              value: _employmentStatus,
              items: CallAnalysisPracticeData.employmentStatuses,
              onChanged: (v) => setState(() => _employmentStatus = v!),
            ),
            const SizedBox(height: 8),
            _sectionTitle('Garanzie e rischio'),
            _yesNoField(
              label: 'Coobbligato',
              value: _hasCoObligor,
              onChanged: (v) => setState(() => _hasCoObligor = v),
            ),
            _yesNoField(
              label: 'Garante',
              value: _hasGuarantor,
              onChanged: (v) => setState(() => _hasGuarantor = v),
            ),
            const SizedBox(height: 8),
            _sectionTitle('Storico recupero'),
            _yesNoField(
              label: 'Ultima promessa mantenuta?',
              value: _lastPromiseKept,
              onChanged: (v) => setState(() => _lastPromiseKept = v),
            ),
            _textField(
              _notesCtrl,
              'Note del consulente',
              hint: 'Informazioni utili per l\'analisi (opzionale)',
              maxLines: 4,
              required: false,
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: TextStyle(color: Colors.red.shade700)),
            ],
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _loading ? null : _submit,
              icon: _loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.psychology_outlined),
              label: Text(_loading ? 'Analisi in corso…' : 'Analizza telefonata'),
            ),
            if (_analysisResult != null) ...[
              const SizedBox(height: 24),
              _sectionTitle('Suggerimenti sulle leve'),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    _analysisResult!,
                    style: const TextStyle(height: 1.5),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
          ],
        ),
      ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 4),
      child: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
      ),
    );
  }

  Widget _textField(
    TextEditingController ctrl,
    String label, {
    String? hint,
    TextInputType keyboard = TextInputType.text,
    bool digitsOnly = false,
    int maxLines = 1,
    bool required = true,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: ctrl,
        maxLines: maxLines,
        keyboardType: keyboard,
        inputFormatters:
            digitsOnly ? [FilteringTextInputFormatter.digitsOnly] : null,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          border: const OutlineInputBorder(),
          alignLabelWithHint: maxLines > 1,
        ),
        validator: validator ??
            (required
                ? (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Campo obbligatorio';
                    }
                    return null;
                  }
                : null),
      ),
    );
  }

  Widget _dropdown({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<String>(
        value: value,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        items: items
            .map((e) => DropdownMenuItem(value: e, child: Text(e)))
            .toList(),
        onChanged: onChanged,
      ),
    );
  }

  Widget _dropdownInt({
    required String label,
    required int value,
    required List<int> items,
    required ValueChanged<int?> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<int>(
        value: value,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        items: items
            .map((e) => DropdownMenuItem(value: e, child: Text('$e')))
            .toList(),
        onChanged: onChanged,
      ),
    );
  }

  Widget _yesNoField({
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        child: Row(
          children: [
            Expanded(
              child: RadioListTile<bool>(
                title: const Text('Sì'),
                value: true,
                groupValue: value,
                onChanged: (v) => onChanged(v ?? false),
                contentPadding: EdgeInsets.zero,
                dense: true,
              ),
            ),
            Expanded(
              child: RadioListTile<bool>(
                title: const Text('No'),
                value: false,
                groupValue: value,
                onChanged: (v) => onChanged(v ?? false),
                contentPadding: EdgeInsets.zero,
                dense: true,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dateField() {
    final label = _lastPaymentDate == null
        ? 'Seleziona data'
        : '${_lastPaymentDate!.day.toString().padLeft(2, '0')}/'
            '${_lastPaymentDate!.month.toString().padLeft(2, '0')}/'
            '${_lastPaymentDate!.year}';
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: _pickLastPaymentDate,
        borderRadius: BorderRadius.circular(4),
        child: InputDecorator(
          decoration: const InputDecoration(
            labelText: 'Data ultimo pagamento',
            border: OutlineInputBorder(),
            suffixIcon: Icon(Icons.calendar_today_outlined),
          ),
          child: Text(
            _lastPaymentDate == null ? 'Tocca per scegliere' : label,
            style: TextStyle(
              color: _lastPaymentDate == null ? Colors.grey.shade600 : null,
            ),
          ),
        ),
      ),
    );
  }
}
