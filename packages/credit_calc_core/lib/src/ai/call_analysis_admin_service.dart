import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'call_analysis_config_service.dart';

typedef CallAnalysisAdminVerifier = Future<bool> Function({
  bool forceRefresh,
});

/// Salvataggio prompt Analisi telefonata (BackOffice app + web).
abstract final class CallAnalysisAdminService {
  static Future<void> savePrompt(
    String prompt, {
    required CallAnalysisAdminVerifier verifyAdmin,
  }) async {
    if (!await verifyAdmin(forceRefresh: true)) {
      throw StateError('Accesso negato');
    }

    final trimmed = prompt.trim();
    if (trimmed.isEmpty) {
      throw StateError('Inserisci il prompt di sistema.');
    }

    final uid = FirebaseAuth.instance.currentUser?.uid;
    await FirebaseFirestore.instance
        .collection('settings')
        .doc(CallAnalysisConfigService.docId)
        .set({
      'prompt': trimmed,
      'updatedAt': FieldValue.serverTimestamp(),
      if (uid != null) 'updatedBy': uid,
    }, SetOptions(merge: true));
  }
}
