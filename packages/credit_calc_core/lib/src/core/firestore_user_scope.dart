import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Query e scritture Firestore limitate all'utente autenticato corrente.
abstract final class FirestoreUserScope {
  static String? get uid => FirebaseAuth.instance.currentUser?.uid;

  static Query<Map<String, dynamic>> creditorsOrdered() {
    final userId = uid;
    if (userId == null) {
      return FirebaseFirestore.instance
          .collection('creditors')
          .where('userId', isEqualTo: '__unauthenticated__');
    }
    return FirebaseFirestore.instance
        .collection('creditors')
        .where('userId', isEqualTo: userId);
  }

  static List<QueryDocumentSnapshot<Map<String, dynamic>>>
      sortCreditorsByCreatedAt(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final sorted =
        List<QueryDocumentSnapshot<Map<String, dynamic>>>.from(docs);
    sorted.sort((a, b) {
      final aTs = a.data()['createdAt'];
      final bTs = b.data()['createdAt'];
      if (aTs is Timestamp && bTs is Timestamp) {
        return aTs.compareTo(bTs);
      }
      return 0;
    });
    return sorted;
  }

  static Map<String, dynamic> withOwner(Map<String, dynamic> data) {
    final userId = uid;
    if (userId != null) {
      data['userId'] = userId;
    }
    return data;
  }

  static Query<Map<String, dynamic>> userCalculations() {
    final userId = uid;
    if (userId == null) {
      return FirebaseFirestore.instance
          .collection('calculations')
          .where('userId', isEqualTo: '__unauthenticated__');
    }
    return FirebaseFirestore.instance
        .collection('calculations')
        .where('userId', isEqualTo: userId);
  }
}
