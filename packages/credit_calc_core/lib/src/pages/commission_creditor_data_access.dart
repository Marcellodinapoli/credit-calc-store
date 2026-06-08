import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/firestore_user_scope.dart';

class CreditorPick {
  final String id;
  final String name;

  const CreditorPick({required this.id, required this.name});
}

String creditorDisplayLabel(int index, Map<String, dynamic> data) {
  final clientName = (data['clientName'] ?? '').toString().trim();
  if (clientName.isNotEmpty) return clientName;

  final name = (data['name'] ?? data['displayLabel'] ?? '').toString().trim();
  if (name.isEmpty) return 'Creditore ${index + 1}';
  if (name.toLowerCase().startsWith('creditore')) return name;
  return 'Creditore ${index + 1}: $name';
}

/// Accesso creditori per picker e impostazioni provvigioni.
abstract class CommissionCreditorDataAccess {
  static CommissionCreditorDataAccess instance =
      FirestoreCommissionCreditorDataAccess();

  Future<List<CreditorPick>> listCreditorsForPicker();

  Future<Map<String, dynamic>?> loadCreditor(String creditorId);

  Future<void> saveCommissionSettings({
    required String creditorId,
    required Map<String, dynamic> commissionSettings,
  });
}

class FirestoreCommissionCreditorDataAccess
    implements CommissionCreditorDataAccess {
  @override
  Future<List<CreditorPick>> listCreditorsForPicker() async {
    final snapshot = await FirestoreUserScope.creditorsOrdered().get();
    final docs = FirestoreUserScope.sortCreditorsByCreatedAt(snapshot.docs);
    return [
      for (var i = 0; i < docs.length; i++)
        CreditorPick(
          id: docs[i].id,
          name: creditorDisplayLabel(i, docs[i].data()),
        ),
    ];
  }

  @override
  Future<Map<String, dynamic>?> loadCreditor(String creditorId) async {
    final doc = await FirebaseFirestore.instance
        .collection('creditors')
        .doc(creditorId)
        .get();
    if (!doc.exists) return null;
    return doc.data();
  }

  @override
  Future<void> saveCommissionSettings({
    required String creditorId,
    required Map<String, dynamic> commissionSettings,
  }) async {
    await FirebaseFirestore.instance.collection('creditors').doc(creditorId).set(
      {
        'commissionSettings': commissionSettings,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }
}
