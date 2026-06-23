import 'package:cloud_firestore/cloud_firestore.dart';

/// Prompt di sistema configurato da BackOffice (`settings/normative_search`).
abstract final class NormativeSearchConfigService {
  static const docId = 'normative_search';

  static Stream<String> watchPrompt() {
    return FirebaseFirestore.instance
        .collection('settings')
        .doc(docId)
        .snapshots()
        .map((snap) => (snap.data()?['prompt'] ?? '').toString());
  }

  static Future<String> loadPrompt() async {
    final snap =
        await FirebaseFirestore.instance.collection('settings').doc(docId).get();
    return (snap.data()?['prompt'] ?? '').toString();
  }
}
