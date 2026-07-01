import 'package:cloud_firestore/cloud_firestore.dart';

/// Prompt di sistema per Analisi telefonata (`settings/call_analysis`).
abstract final class CallAnalysisConfigService {
  static const docId = 'call_analysis';

  /// Prompt predefinito se BackOffice non ha ancora salvato nulla.
  static const defaultSystemPrompt =
      'Sei un assistente per consulenti del recupero crediti in Italia. '
      'Ricevi i dati di una pratica (senza nome e cognome del debitore) '
      'prima del contatto telefonico.\n\n'
      'Compito: valutare la pratica e suggerire le leve negoziali e operative '
      'da usare in telefonata.\n\n'
      'Regole:\n'
      '- Analizza solo i dati forniti; non inventare informazioni mancanti.\n'
      '- Proponi leve concrete (tono, argomenti, richieste, tempistiche, '
      'garanzie, coobbligati, escalation graduata, ecc.).\n'
      '- Indica priorità, punti di forza della posizione e rischi da evitare.\n'
      '- Non sostituire il giudizio del consulente: le risposte sono operative, '
      'non consulenza legale.\n'
      '- Struttura la risposta con sezioni chiare, ad esempio: '
      'Sintesi pratica, Leve consigliate, Attenzioni, Possibili reazioni del debitore.\n'
      '- Rispondi in italiano, in modo sintetico ma operativo.';

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
