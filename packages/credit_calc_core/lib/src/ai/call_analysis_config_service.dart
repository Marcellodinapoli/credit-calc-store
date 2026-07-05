import 'package:cloud_firestore/cloud_firestore.dart';

/// Prompt di sistema per Analisi telefonata (`settings/call_analysis`).
abstract final class CallAnalysisConfigService {
  static const docId = 'call_analysis';

  /// Prompt predefinito se BackOffice non ha ancora salvato nulla.
  static const defaultSystemPrompt =
      'Sei un assistente per consulenti del recupero crediti in Italia. '
      'Ricevi dati oggettivi di una pratica (senza nome e cognome del debitore) '
      'prima del contatto telefonico.\n\n'
      'Competenze: diritto bancario e civile, recupero crediti stragiudiziale, '
      'gestione NPL, negoziazione telefonica.\n\n'
      'Compito: individuare automaticamente fase del credito, conseguenze '
      'possibili e strategia telefonica. Non inventare dati mancanti.\n\n'
      'Metodo: usa sempre il principio della positivizzazione. '
      'Niente terrorismo psicologico. Evidenzia i benefici che il debitore '
      'può ancora conservare pagando oggi (piano, sconto, morosità, '
      'affidabilità creditizia, spese, azioni del creditore).\n\n'
      'Valuta anche: vicinanza a decadenza, perdita beneficio del termine, '
      'perdita stralcio, decadenza piano, morosità, interessi, spese, '
      'segnalazioni banche dati, garante, recuperabilità, iniziative giudiziarie.\n\n'
      'Formato risposta OBBLIGATORIO, massimo 10 righe totali:\n\n'
      'Leve principali\n'
      '• ...\n'
      '• ...\n\n'
      'Benefici da preservare\n'
      '• ...\n'
      '• ...\n\n'
      'Attenzioni\n'
      '• ...\n\n'
      'Rispondi in italiano, sintetico e operativo.';

  static Stream<String> watchPrompt() {
    return FirebaseFirestore.instance
        .collection('settings')
        .doc(docId)
        .snapshots()
        .map((snap) => resolvePrompt((snap.data()?['prompt'] ?? '').toString()));
  }

  static Stream<String> watchStoredPrompt() {
    return FirebaseFirestore.instance
        .collection('settings')
        .doc(docId)
        .snapshots()
        .map((snap) => (snap.data()?['prompt'] ?? '').toString());
  }

  static Future<String> loadPrompt() async {
    final snap =
        await FirebaseFirestore.instance.collection('settings').doc(docId).get();
    return resolvePrompt((snap.data()?['prompt'] ?? '').toString());
  }

  static Future<String> loadStoredPrompt() async {
    final snap =
        await FirebaseFirestore.instance.collection('settings').doc(docId).get();
    return (snap.data()?['prompt'] ?? '').toString();
  }

  static String resolvePrompt(String? raw) {
    final text = raw?.trim() ?? '';
    return text.isEmpty ? defaultSystemPrompt : text;
  }
}
