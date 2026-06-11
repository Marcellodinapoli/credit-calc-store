import 'package:cloud_firestore/cloud_firestore.dart';

class FieldActivity {
  const FieldActivity({
    required this.id,
    required this.userId,
    required this.title,
    required this.completed,
    this.notes,
    this.dueAt,
    this.visitId,
    this.recurrenceDays,
  });

  final String id;
  final String userId;
  final String title;
  final bool completed;
  final String? notes;
  final DateTime? dueAt;
  final String? visitId;
  final int? recurrenceDays;

  factory FieldActivity.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    final due = data['dueAt'];
    return FieldActivity(
      id: doc.id,
      userId: (data['userId'] ?? '').toString(),
      title: (data['title'] ?? '').toString().trim(),
      completed: data['completed'] == true,
      notes: data['notes']?.toString(),
      dueAt: due is Timestamp ? due.toDate() : null,
      visitId: data['visitId']?.toString(),
      recurrenceDays: data['recurrenceDays'] is int
          ? data['recurrenceDays'] as int
          : int.tryParse(data['recurrenceDays']?.toString() ?? ''),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'title': title,
      'completed': completed,
      if (notes != null && notes!.isNotEmpty) 'notes': notes,
      if (dueAt != null) 'dueAt': Timestamp.fromDate(dueAt!),
      if (visitId != null && visitId!.isNotEmpty) 'visitId': visitId,
      if (recurrenceDays != null && recurrenceDays! > 0)
        'recurrenceDays': recurrenceDays,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}
