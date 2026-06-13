import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Ultima simulazione roleplay del collaboratore (un solo record, sempre sovrascritto).
abstract final class RoleplayProgressService {
  RoleplayProgressService._();

  static const collection = 'roleplay_progress';

  static DocumentReference<Map<String, dynamic>> _doc(String userId) =>
      FirebaseFirestore.instance.collection(collection).doc(userId);

  /// Salva/sovrascrive l'ultima simulazione completata o interrotta.
  static Future<void> saveLastSimulation({
    required String simulationId,
    required String title,
    required String category,
    required List<dynamic> practiceData,
    required int userExchanges,
    required int totalMessages,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      await _doc(uid).set({
        'userId': uid,
        'simulationId': simulationId,
        'title': title,
        'category': category,
        'practiceData': practiceData,
        'userExchanges': userExchanges,
        'totalMessages': totalMessages,
        'completedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e) {
      debugPrint('RoleplayProgressService.saveLastSimulation → ${e.code}');
    }
  }

  static RoleplayLastSimulation? fromDoc(
    DocumentSnapshot<Map<String, dynamic>> snap,
  ) {
    if (!snap.exists) return null;
    final data = snap.data();
    if (data == null) return null;

    final title = (data['title'] ?? '').toString().trim();
    if (title.isEmpty) return null;

    return RoleplayLastSimulation(
      simulationId: (data['simulationId'] ?? '').toString(),
      title: title,
      category: (data['category'] ?? '').toString(),
      practiceData: List<Map<String, dynamic>>.from(
        (data['practiceData'] as List<dynamic>? ?? []).map(
          (e) => e is Map
              ? Map<String, dynamic>.from(e)
              : <String, dynamic>{},
        ),
      ),
      userExchanges: (data['userExchanges'] as num?)?.toInt() ?? 0,
      totalMessages: (data['totalMessages'] as num?)?.toInt() ?? 0,
      completedAt: (data['completedAt'] as Timestamp?)?.toDate(),
    );
  }
}

class RoleplayLastSimulation {
  const RoleplayLastSimulation({
    required this.simulationId,
    required this.title,
    required this.category,
    required this.practiceData,
    required this.userExchanges,
    required this.totalMessages,
    this.completedAt,
  });

  final String simulationId;
  final String title;
  final String category;
  final List<Map<String, dynamic>> practiceData;
  final int userExchanges;
  final int totalMessages;
  final DateTime? completedAt;
}
