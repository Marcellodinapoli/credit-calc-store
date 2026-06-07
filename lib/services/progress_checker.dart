import 'package:cloud_firestore/cloud_firestore.dart';

/// Ritorna true solo se TUTTI i corsi PRE sono completati
Future<bool> hasCompletedPreContenzioso(String uid) async {
  final snap = await FirebaseFirestore.instance
      .collection('userProgress')
      .doc(uid)
      .collection('courses')
      .where('category', isEqualTo: 'pre')
      .get();

  if (snap.docs.isEmpty) return false;

  for (final doc in snap.docs) {
    final data = doc.data();
    final videoCompleted = (data['videoViews'] ?? 0) > 0;
    final quizCompleted = (data['lastScore'] ?? 0) >= 70;

    if (!videoCompleted || !quizCompleted) {
      return false;
    }
  }

  return true;
}
