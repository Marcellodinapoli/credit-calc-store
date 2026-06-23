import 'package:cloud_firestore/cloud_firestore.dart';

abstract final class CallAnalysisConfigService {
  static const docId = 'call_analysis';

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
