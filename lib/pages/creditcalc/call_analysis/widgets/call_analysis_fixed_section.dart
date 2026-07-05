import 'package:flutter/material.dart';

import '../../../../models/call_analysis/call_analysis_form_config.dart';
import 'call_analysis_form_fields.dart';

class CallAnalysisFixedSection extends StatelessWidget {
  const CallAnalysisFixedSection({
    super.key,
    required this.creditType,
    required this.creditorCtrl,
    required this.ageCtrl,
    required this.employmentStatus,
    required this.guarantorSituation,
    required this.onCreditTypeChanged,
    required this.onEmploymentChanged,
    required this.onGuarantorChanged,
  });

  final String creditType;
  final TextEditingController creditorCtrl;
  final TextEditingController ageCtrl;
  final String employmentStatus;
  final String guarantorSituation;
  final ValueChanged<String?> onCreditTypeChanged;
  final ValueChanged<String?> onEmploymentChanged;
  final ValueChanged<String?> onGuarantorChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CallAnalysisFormFields.sectionTitle('Dati pratica'),
        CallAnalysisFormFields.dropdown(
          label: 'Tipologia credito',
          value: creditType,
          items: CallAnalysisFormConfig.creditTypes,
          labelBuilder: (v) => v,
          onChanged: onCreditTypeChanged,
        ),
        CallAnalysisFormFields.textField(
          controller: creditorCtrl,
          label: 'Creditore',
          required: true,
        ),
        CallAnalysisFormFields.textField(
          controller: ageCtrl,
          label: 'Età debitore',
          keyboard: TextInputType.number,
          digitsOnly: true,
          required: true,
          validator: (v) {
            final n = int.tryParse((v ?? '').trim());
            if (n == null || n < 18 || n > 110) return 'Età non valida';
            return null;
          },
        ),
        CallAnalysisFormFields.dropdown(
          label: 'Situazione lavorativa',
          value: employmentStatus,
          items: CallAnalysisFormConfig.employmentStatuses,
          labelBuilder: (v) => v,
          onChanged: onEmploymentChanged,
        ),
        CallAnalysisFormFields.dropdown(
          label: 'Garante',
          value: guarantorSituation,
          items: CallAnalysisFormConfig.guarantorOptions,
          labelBuilder: (v) => v,
          onChanged: onGuarantorChanged,
        ),
      ],
    );
  }
}
