import 'package:flutter/material.dart';

import '../../../../models/call_analysis/call_analysis_form_config.dart';
import 'call_analysis_form_fields.dart';

class PianoRientroSection extends StatelessWidget {
  const PianoRientroSection({
    super.key,
    required this.agreementCtrl,
    required this.plannedCtrl,
    required this.paidCtrl,
    required this.unpaidCtrl,
    required this.paymentMethod,
    required this.onPaymentMethodChanged,
  });

  final TextEditingController agreementCtrl;
  final TextEditingController plannedCtrl;
  final TextEditingController paidCtrl;
  final TextEditingController unpaidCtrl;
  final String? paymentMethod;
  final ValueChanged<String?> onPaymentMethodChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CallAnalysisFormFields.sectionTitle('Piano di rientro'),
        CallAnalysisFormFields.textField(
          controller: agreementCtrl,
          label: 'Importo accordo',
          required: false,
        ),
        CallAnalysisFormFields.textField(
          controller: plannedCtrl,
          label: 'Rate previste',
          keyboard: TextInputType.number,
          digitsOnly: true,
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
          controller: unpaidCtrl,
          label: 'Rate insolute',
          keyboard: TextInputType.number,
          digitsOnly: true,
          required: false,
        ),
        CallAnalysisFormFields.dropdown<String?>(
          label: 'Modalità pagamento',
          value: paymentMethod,
          items: [null, ...CallAnalysisFormConfig.paymentMethodOptions],
          labelBuilder: (v) => v ?? '—',
          onChanged: onPaymentMethodChanged,
          required: false,
        ),
      ],
    );
  }
}
