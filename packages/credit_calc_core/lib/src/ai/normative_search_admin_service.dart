import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'normative_search_config_service.dart';

typedef NormativeSearchAdminVerifier = Future<bool> Function({
  bool forceRefresh,
});

/// Salvataggio prompt Ricerca normativa (BackOffice app + web).
abstract final class NormativeSearchAdminService {
  static Future<void> savePrompt(
    String prompt, {
    required NormativeSearchAdminVerifier verifyAdmin,
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
        .doc(NormativeSearchConfigService.docId)
        .set({
      'prompt': trimmed,
      'updatedAt': FieldValue.serverTimestamp(),
      if (uid != null) 'updatedBy': uid,
    }, SetOptions(merge: true));
  }
}
