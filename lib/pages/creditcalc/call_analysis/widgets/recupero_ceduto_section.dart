import 'package:flutter/material.dart';

import '../../../../models/call_analysis/call_analysis_form_config.dart';
import 'call_analysis_form_fields.dart';

class RecuperoCedutoSection extends StatelessWidget {
  const RecuperoCedutoSection({
    super.key,
    required this.assignmentNumber,
    required this.remainingDebtCtrl,
    required this.lastPaymentDate,
    required this.recoveredAmountCtrl,
    required this.recoveryHistory,
    required this.onAssignmentChanged,
    required this.onLastPaymentChanged,
    required this.onRecoveryHistoryChanged,
  });

  final String? assignmentNumber;
  final TextEditingController remainingDebtCtrl;
  final DateTime? lastPaymentDate;
  final TextEditingController recoveredAmountCtrl;
  final String? recoveryHistory;
  final ValueChanged<String?> onAssignmentChanged;
  final ValueChanged<DateTime?> onLastPaymentChanged;
  final ValueChanged<String?> onRecoveryHistoryChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CallAnalysisFormFields.sectionTitle('Recupero credito ceduto'),
        CallAnalysisFormFields.dropdown<String?>(
          label: 'Numero cessione',
          value: assignmentNumber,
          items: [null, ...CallAnalysisFormConfig.assignmentNumberOptions],
          labelBuilder: (v) => v ?? '—',
          onChanged: onAssignmentChanged,
          required: false,
        ),
        CallAnalysisFormFields.textField(
          controller: remainingDebtCtrl,
          label: 'Debito residuo',
          required: false,
        ),
        CallAnalysisFormFields.dateField(
          context: context,
          label: 'Ultimo pagamento',
          value: lastPaymentDate,
          onChanged: onLastPaymentChanged,
        ),
        CallAnalysisFormFields.textField(
          controller: recoveredAmountCtrl,
          label: 'Importo già recuperato',
          required: false,
        ),
        CallAnalysisFormFields.dropdown<String?>(
          label: 'Storico recupero',
          value: recoveryHistory,
          items: [null, ...CallAnalysisFormConfig.recoveryHistoryOptions],
          labelBuilder: (v) => v ?? '—',
          onChanged: onRecoveryHistoryChanged,
          required: false,
        ),
      ],
    );
  }
}
