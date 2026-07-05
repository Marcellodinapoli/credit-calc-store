import 'package:flutter/material.dart';

import '../../../../models/call_analysis/call_analysis_form_config.dart';
import 'call_analysis_form_fields.dart';

class MonitoraggioOriginatorSection extends StatelessWidget {
  const MonitoraggioOriginatorSection({
    super.key,
    required this.unpaidInstallments,
    required this.installmentCtrl,
    required this.paidCtrl,
    required this.totalCtrl,
    required this.remainingDebtCtrl,
    required this.lastPaymentDate,
    required this.insolvencyHistory,
    required this.defaultManagement,
    required this.onUnpaidChanged,
    required this.onLastPaymentChanged,
    required this.onInsolvencyChanged,
    required this.onDefaultManagementChanged,
  });

  final int? unpaidInstallments;
  final TextEditingController installmentCtrl;
  final TextEditingController paidCtrl;
  final TextEditingController totalCtrl;
  final TextEditingController remainingDebtCtrl;
  final DateTime? lastPaymentDate;
  final String? insolvencyHistory;
  final String? defaultManagement;
  final ValueChanged<int?> onUnpaidChanged;
  final ValueChanged<DateTime?> onLastPaymentChanged;
  final ValueChanged<String?> onInsolvencyChanged;
  final ValueChanged<String?> onDefaultManagementChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CallAnalysisFormFields.sectionTitle('Monitoraggio Originator'),
        CallAnalysisFormFields.dropdown<int?>(
          label: 'Numero rate insolute',
          value: unpaidInstallments,
          items: [null, ...CallAnalysisFormConfig.unpaidInstallmentsValues],
          labelBuilder: (v) => v == null ? '—' : '$v',
          onChanged: onUnpaidChanged,
          required: false,
        ),
        CallAnalysisFormFields.textField(
          controller: installmentCtrl,
          label: 'Importo rata',
          hint: 'Es. 150,00 €',
          required: false,
        ),
        CallAnalysisFormFields.textField(
          controller: paidCtrl,
          label: 'Rate pagate',
          keyboard: TextInputType.number,
          digitsOnly: true,
          required: false,
        ),
        CallAnalysisFormFields.textField(
          controller: totalCtrl,
          label: 'Rate totali',
          keyboard: TextInputType.number,
          digitsOnly: true,
          required: false,
        ),
        CallAnalysisFormFields.textField(
          controller: remainingDebtCtrl,
          label: 'Debito residuo',
          hint: 'Es. 1.200,00 €',
          required: false,
        ),
        CallAnalysisFormFields.dateField(
          context: context,
          label: 'Ultimo pagamento',
          value: lastPaymentDate,
          onChanged: onLastPaymentChanged,
        ),
        CallAnalysisFormFields.dropdown<String?>(
          label: 'Storico insolvenza',
          value: insolvencyHistory,
          items: [
            null,
            ...CallAnalysisFormConfig.insolvencyHistoryOptions,
          ],
          labelBuilder: (v) => v ?? '—',
          onChanged: onInsolvencyChanged,
          required: false,
        ),
        CallAnalysisFormFields.dropdown<String?>(
          label: 'Gestione morosità',
          value: defaultManagement,
          items: [
            null,
            ...CallAnalysisFormConfig.defaultManagementOptions,
          ],
          labelBuilder: (v) => v ?? '—',
          onChanged: onDefaultManagementChanged,
          required: false,
        ),
      ],
    );
  }
}
