import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'bk_admin_service.dart';
import '../../services/normative_search_config_service.dart';

abstract final class NormativeSearchAdminService {
  static Future<void> savePrompt(String prompt) async {
    if (!await BkAdminService.isAdmin(forceRefresh: true)) {
      throw StateError('Accesso negato');
    }

    final uid = FirebaseAuth.instance.currentUser?.uid;
    await FirebaseFirestore.instance
        .collection('settings')
        .doc(NormativeSearchConfigService.docId)
        .set({
      'prompt': prompt.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
      if (uid != null) 'updatedBy': uid,
    }, SetOptions(merge: true));
  }
}
