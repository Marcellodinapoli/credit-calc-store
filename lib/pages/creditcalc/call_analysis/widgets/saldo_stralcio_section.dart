import 'package:flutter/material.dart';

import '../../../../models/call_analysis/call_analysis_form_config.dart';
import 'call_analysis_form_fields.dart';

class SaldoStralcioSection extends StatelessWidget {
  const SaldoStralcioSection({
    super.key,
    required this.originalCtrl,
    required this.agreedCtrl,
    required this.paidCtrl,
    required this.remainingCtrl,
    required this.paymentMethod,
    required this.onPaymentMethodChanged,
  });

  final TextEditingController originalCtrl;
  final TextEditingController agreedCtrl;
  final TextEditingController paidCtrl;
  final TextEditingController remainingCtrl;
  final String? paymentMethod;
  final ValueChanged<String?> onPaymentMethodChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CallAnalysisFormFields.sectionTitle('Saldo e stralcio'),
        CallAnalysisFormFields.textField(
          controller: originalCtrl,
          label: 'Importo originario',
          required: false,
        ),
        CallAnalysisFormFields.textField(
          controller: agreedCtrl,
          label: 'Importo concordato',
          required: false,
        ),
        CallAnalysisFormFields.textField(
          controller: paidCtrl,
          label: 'Importo pagato',
          required: false,
        ),
        CallAnalysisFormFields.textField(
          controller: remainingCtrl,
          label: 'Importo residuo',
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
