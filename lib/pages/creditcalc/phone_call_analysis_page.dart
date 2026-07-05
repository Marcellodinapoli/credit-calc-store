import 'package:credit_calc_core/credit_calc_core.dart';
import 'package:flutter/material.dart';

import '../../core/maintenance_service.dart';
import '../../models/call_analysis/call_analysis_form_config.dart';
import '../../models/call_analysis/call_analysis_form_data.dart';
import '../../services/call_analysis_service.dart';
import '../../ui/layout/page_shell.dart';
import '../../widgets/maintenance_section_gate.dart';
import 'call_analysis/widgets/call_analysis_fixed_section.dart';
import 'call_analysis/widgets/call_analysis_form_fields.dart';
import 'call_analysis/widgets/call_analysis_practice_module_host.dart';
import 'call_analysis/widgets/monitoraggio_originator_section.dart';
import 'call_analysis/widgets/piano_rientro_section.dart';
import 'call_analysis/widgets/recupero_ceduto_section.dart';
import 'call_analysis/widgets/saldo_stralcio_section.dart';

/// Analisi Strategica Pre-Contatto — form oggettivo + suggerimenti AI.
class PhoneCallAnalysisPage extends StatefulWidget {
  const PhoneCallAnalysisPage({super.key});

  @override
  State<PhoneCallAnalysisPage> createState() => _PhoneCallAnalysisPageState();
}

class _PhoneCallAnalysisPageState extends State<PhoneCallAnalysisPage> {
  final _formKey = GlobalKey<FormState>();

  final _creditorCtrl = TextEditingController();
  final _ageCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  final _monInstallmentCtrl = TextEditingController();
  final _monPaidCtrl = TextEditingController();
  final _monTotalCtrl = TextEditingController();
  final _monRemainingCtrl = TextEditingController();

  final _recRemainingCtrl = TextEditingController();
  final _recRecoveredCtrl = TextEditingController();

  final _pianoAgreementCtrl = TextEditingController();
  final _pianoPlannedCtrl = TextEditingController();
  final _pianoPaidCtrl = TextEditingController();
  final _pianoUnpaidCtrl = TextEditingController();

  final _saldoOriginalCtrl = TextEditingController();
  final _saldoAgreedCtrl = TextEditingController();
  final _saldoPaidCtrl = TextEditingController();
  final _saldoRemainingCtrl = TextEditingController();

  String _creditType = CallAnalysisFormConfig.creditTypes.first;
  String _employmentStatus = CallAnalysisFormConfig.employmentStatuses.first;
  String _guarantorSituation = CallAnalysisFormConfig.guarantorOptions.first;
  String? _practiceStateKey;

  int? _monUnpaid;
  DateTime? _monLastPayment;
  String? _monInsolvency;
  String? _monDefaultMgmt;

  String? _recAssignment;
  DateTime? _recLastPayment;
  String? _recHistory;

  String? _pianoPayment;
  String? _saldoPayment;

  bool _loading = false;
  String? _error;
  String? _analysisResult;

  @override
  void dispose() {
    _creditorCtrl.dispose();
    _ageCtrl.dispose();
    _notesCtrl.dispose();
    _monInstallmentCtrl.dispose();
    _monPaidCtrl.dispose();
    _monTotalCtrl.dispose();
    _monRemainingCtrl.dispose();
    _recRemainingCtrl.dispose();
    _recRecoveredCtrl.dispose();
    _pianoAgreementCtrl.dispose();
    _pianoPlannedCtrl.dispose();
    _pianoPaidCtrl.dispose();
    _pianoUnpaidCtrl.dispose();
    _saldoOriginalCtrl.dispose();
    _saldoAgreedCtrl.dispose();
    _saldoPaidCtrl.dispose();
    _saldoRemainingCtrl.dispose();
    super.dispose();
  }

  String? _optionalText(TextEditingController c) {
    final t = c.text.trim();
    return t.isEmpty ? null : t;
  }

  CallAnalysisFormData _buildFormData() {
    final key = _practiceStateKey!;
    return CallAnalysisFormData(
      creditType: _creditType,
      creditor: _creditorCtrl.text.trim(),
      debtorAge: int.parse(_ageCtrl.text.trim()),
      employmentStatus: _employmentStatus,
      guarantorSituation: _guarantorSituation,
      practiceStateKey: key,
      monitoraggio: key == CallAnalysisFormConfig.monitoraggioOriginator
          ? MonitoraggioOriginatorFields(
              unpaidInstallments: _monUnpaid,
              installmentAmount: _optionalText(_monInstallmentCtrl),
              paidInstallments: _optionalText(_monPaidCtrl),
              totalInstallments: _optionalText(_monTotalCtrl),
              remainingDebt: _optionalText(_monRemainingCtrl),
              lastPaymentDate: _monLastPayment,
              insolvencyHistory: _monInsolvency,
              defaultManagement: _monDefaultMgmt,
            )
          : null,
      recupero: key == CallAnalysisFormConfig.recuperoCeduto
          ? RecuperoCedutoFields(
              assignmentNumber: _recAssignment,
              remainingDebt: _optionalText(_recRemainingCtrl),
              lastPaymentDate: _recLastPayment,
              recoveredAmount: _optionalText(_recRecoveredCtrl),
              recoveryHistory: _recHistory,
            )
          : null,
      piano: key == CallAnalysisFormConfig.pianoRientro
          ? PianoRientroFields(
              agreementAmount: _optionalText(_pianoAgreementCtrl),
              plannedInstallments: _optionalText(_pianoPlannedCtrl),
              paidInstallments: _optionalText(_pianoPaidCtrl),
              unpaidInstallments: _optionalText(_pianoUnpaidCtrl),
              paymentMethod: _pianoPayment,
            )
          : null,
      saldo: key == CallAnalysisFormConfig.saldoStralcio
          ? SaldoStralcioFields(
              originalAmount: _optionalText(_saldoOriginalCtrl),
              agreedAmount: _optionalText(_saldoAgreedCtrl),
              paidAmount: _optionalText(_saldoPaidCtrl),
              remainingAmount: _optionalText(_saldoRemainingCtrl),
              paymentMethod: _saldoPayment,
            )
          : null,
      consultantNotes: _optionalText(_notesCtrl),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_practiceStateKey == null) {
      setState(() => _error = 'Seleziona lo stato della pratica.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _analysisResult = null;
    });

    try {
      final practice = _buildFormData();
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
    } catch (_) {
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
      pageTitle: 'Analisi Strategica Pre-Contatto',
      project: BrandedPageProject.calc,
      body: MaintenanceSectionGate(
        sectionName: MaintenanceService.creditCalc,
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Compila solo dati oggettivi in meno di un minuto. '
                'L\'AI analizza la pratica e suggerisce la strategia telefonica.',
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
              CallAnalysisFixedSection(
                creditType: _creditType,
                creditorCtrl: _creditorCtrl,
                ageCtrl: _ageCtrl,
                employmentStatus: _employmentStatus,
                guarantorSituation: _guarantorSituation,
                onCreditTypeChanged: (v) =>
                    setState(() => _creditType = v ?? _creditType),
                onEmploymentChanged: (v) =>
                    setState(() => _employmentStatus = v ?? _employmentStatus),
                onGuarantorChanged: (v) => setState(
                  () => _guarantorSituation = v ?? _guarantorSituation,
                ),
              ),
              const SizedBox(height: 8),
              CallAnalysisFormFields.practiceStateDropdown(
                value: _practiceStateKey,
                onChanged: (v) => setState(() => _practiceStateKey = v),
              ),
              CallAnalysisPracticeModuleHost(
                practiceStateKey: _practiceStateKey,
                monitoraggio: MonitoraggioOriginatorSection(
                  unpaidInstallments: _monUnpaid,
                  installmentCtrl: _monInstallmentCtrl,
                  paidCtrl: _monPaidCtrl,
                  totalCtrl: _monTotalCtrl,
                  remainingDebtCtrl: _monRemainingCtrl,
                  lastPaymentDate: _monLastPayment,
                  insolvencyHistory: _monInsolvency,
                  defaultManagement: _monDefaultMgmt,
                  onUnpaidChanged: (v) => setState(() => _monUnpaid = v),
                  onLastPaymentChanged: (v) =>
                      setState(() => _monLastPayment = v),
                  onInsolvencyChanged: (v) =>
                      setState(() => _monInsolvency = v),
                  onDefaultManagementChanged: (v) =>
                      setState(() => _monDefaultMgmt = v),
                ),
                recupero: RecuperoCedutoSection(
                  assignmentNumber: _recAssignment,
                  remainingDebtCtrl: _recRemainingCtrl,
                  lastPaymentDate: _recLastPayment,
                  recoveredAmountCtrl: _recRecoveredCtrl,
                  recoveryHistory: _recHistory,
                  onAssignmentChanged: (v) =>
                      setState(() => _recAssignment = v),
                  onLastPaymentChanged: (v) =>
                      setState(() => _recLastPayment = v),
                  onRecoveryHistoryChanged: (v) =>
                      setState(() => _recHistory = v),
                ),
                piano: PianoRientroSection(
                  agreementCtrl: _pianoAgreementCtrl,
                  plannedCtrl: _pianoPlannedCtrl,
                  paidCtrl: _pianoPaidCtrl,
                  unpaidCtrl: _pianoUnpaidCtrl,
                  paymentMethod: _pianoPayment,
                  onPaymentMethodChanged: (v) =>
                      setState(() => _pianoPayment = v),
                ),
                saldo: SaldoStralcioSection(
                  originalCtrl: _saldoOriginalCtrl,
                  agreedCtrl: _saldoAgreedCtrl,
                  paidCtrl: _saldoPaidCtrl,
                  remainingCtrl: _saldoRemainingCtrl,
                  paymentMethod: _saldoPayment,
                  onPaymentMethodChanged: (v) =>
                      setState(() => _saldoPayment = v),
                ),
              ),
              const SizedBox(height: 8),
              CallAnalysisFormFields.sectionTitle('Note'),
              CallAnalysisFormFields.textField(
                controller: _notesCtrl,
                label: 'Note del consulente',
                hint:
                    'Informazioni raccolte, comportamento, criticità, famiglia, '
                    'disponibilità economica…',
                maxLines: 5,
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
                label: Text(_loading ? 'Analisi in corso…' : 'Analizza con AI'),
              ),
              if (_analysisResult != null) ...[
                const SizedBox(height: 24),
                CallAnalysisFormFields.sectionTitle('Analisi AI'),
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
}
