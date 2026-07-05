import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NormativeSearchLogEntry {
  const NormativeSearchLogEntry({
    required this.id,
    required this.userId,
    required this.userEmail,
    required this.question,
    required this.answer,
    required this.answerPreview,
    required this.inputTokens,
    required this.outputTokens,
    required this.createdAt,
  });

  final String id;
  final String userId;
  final String? userEmail;
  final String question;
  final String answer;
  final String answerPreview;
  final int inputTokens;
  final int outputTokens;
  final DateTime? createdAt;

  String get userLabel {
    final email = userEmail?.trim();
    if (email != null && email.isNotEmpty) return email;
    if (userId.length <= 10) return userId;
    return '${userId.substring(0, 8)}…';
  }

  factory NormativeSearchLogEntry.fromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    final createdAt = data['createdAt'];
    return NormativeSearchLogEntry(
      id: doc.id,
      userId: (data['userId'] ?? '').toString(),
      userEmail: data['userEmail']?.toString(),
      question: (data['question'] ?? '').toString(),
      answer: (data['answer'] ?? '').toString(),
      answerPreview: (data['answerPreview'] ?? '').toString(),
      inputTokens: (data['inputTokens'] as num?)?.toInt() ?? 0,
      outputTokens: (data['outputTokens'] as num?)?.toInt() ?? 0,
      createdAt: createdAt is Timestamp ? createdAt.toDate() : null,
    );
  }
}

abstract final class NormativeSearchLogService {
  static const collection = 'normative_search_logs';
  static const defaultLimit = 100;

  static Stream<List<NormativeSearchLogEntry>> watchRecent({
    int limit = defaultLimit,
  }) {
    return FirebaseFirestore.instance
        .collection(collection)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map(NormativeSearchLogEntry.fromDoc)
              .toList(growable: false),
        );
  }

  static Stream<List<NormativeSearchLogEntry>> watchMine({
    int limit = defaultLimit,
  }) {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      return Stream.value(const []);
    }

    return FirebaseFirestore.instance
        .collection(collection)
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map(NormativeSearchLogEntry.fromDoc)
              .toList(growable: false),
        );
  }
}
