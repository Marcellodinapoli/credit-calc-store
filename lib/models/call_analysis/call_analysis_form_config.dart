/// Opzioni configurabili del form Analisi Strategica Pre-Contatto.
abstract final class CallAnalysisFormConfig {
  static const creditTypes = [
    'Prestito personale',
    'Carta revolving',
    'Cessione del quinto',
    'Mutuo',
    'Leasing',
    'Finanziamento auto',
    'Finanziamento finalizzato',
    'Altro',
  ];

  static const employmentStatuses = [
    'Dipendente',
    'Autonomo',
    'Pensionato',
    'Disoccupato',
    'Non nota',
  ];

  static const guarantorOptions = [
    'Nessuno',
    'Presente',
  ];

  static const practiceStates = [
    PracticeStateOption(
      key: monitoraggioOriginator,
      label: 'Monitoraggio Originator',
    ),
    PracticeStateOption(
      key: recuperoCeduto,
      label: 'Recupero credito ceduto',
    ),
    PracticeStateOption(
      key: pianoRientro,
      label: 'Piano di rientro',
    ),
    PracticeStateOption(
      key: saldoStralcio,
      label: 'Saldo e stralcio',
    ),
  ];

  static const monitoraggioOriginator = 'monitoraggio_originator';
  static const recuperoCeduto = 'recupero_ceduto';
  static const pianoRientro = 'piano_rientro';
  static const saldoStralcio = 'saldo_stralcio';

  static const unpaidInstallmentsValues = [1, 2, 3, 4, 5, 6, 7];

  static const insolvencyHistoryOptions = [
    'Primo episodio',
    'Insolvenze occasionali',
    'Insolvenze frequenti',
  ];

  static const defaultManagementOptions = [
    'Paga rata e morosità',
    'Paga solo rata',
    'Non regolarizza',
  ];

  static const assignmentNumberOptions = [
    'Prima',
    'Seconda',
    'Terza o successive',
  ];

  static const recoveryHistoryOptions = [
    'Collaborativo',
    'Saltuario',
    'Nessuna collaborazione',
  ];

  static const paymentMethodOptions = [
    'Bonifico',
    'Bollettino',
    'Cambiali',
    'Altro',
  ];

  static String? labelForPracticeState(String? key) {
    if (key == null) return null;
    for (final state in practiceStates) {
      if (state.key == key) return state.label;
    }
    return null;
  }
}

class PracticeStateOption {
  const PracticeStateOption({required this.key, required this.label});

  final String key;
  final String label;
}
