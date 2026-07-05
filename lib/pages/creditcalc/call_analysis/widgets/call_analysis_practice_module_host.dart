import 'package:flutter/material.dart';

import '../../../../models/call_analysis/call_analysis_form_config.dart';
import 'call_analysis_form_fields.dart';
import 'monitoraggio_originator_section.dart';
import 'piano_rientro_section.dart';
import 'recupero_ceduto_section.dart';
import 'saldo_stralcio_section.dart';

/// Carica dinamicamente il modulo in base allo stato pratica selezionato.
class CallAnalysisPracticeModuleHost extends StatelessWidget {
  const CallAnalysisPracticeModuleHost({
    super.key,
    required this.practiceStateKey,
    required this.monitoraggio,
    required this.recupero,
    required this.piano,
    required this.saldo,
  });

  final String? practiceStateKey;
  final MonitoraggioOriginatorSection monitoraggio;
  final RecuperoCedutoSection recupero;
  final PianoRientroSection piano;
  final SaldoStralcioSection saldo;

  @override
  Widget build(BuildContext context) {
    if (practiceStateKey == null) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        CallAnalysisFormFields.sectionTitle('Dettaglio pratica'),
        switch (practiceStateKey!) {
          CallAnalysisFormConfig.monitoraggioOriginator => monitoraggio,
          CallAnalysisFormConfig.recuperoCeduto => recupero,
          CallAnalysisFormConfig.pianoRientro => piano,
          CallAnalysisFormConfig.saldoStralcio => saldo,
          _ => const SizedBox.shrink(),
        },
      ],
    );
  }
}
