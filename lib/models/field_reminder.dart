import 'package:cloud_firestore/cloud_firestore.dart';

class FieldReminder {
  const FieldReminder({
    required this.id,
    required this.userId,
    required this.title,
    required this.remindAt,
    this.notes,
    this.visitId,
    this.pushSent = false,
  });

  final String id;
  final String userId;
  final String title;
  final DateTime remindAt;
  final String? notes;
  final String? visitId;
  final bool pushSent;

  factory FieldReminder.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    final remind = data['remindAt'];
    return FieldReminder(
      id: doc.id,
      userId: (data['userId'] ?? '').toString(),
      title: (data['title'] ?? '').toString().trim(),
      remindAt: remind is Timestamp ? remind.toDate() : DateTime.now(),
      notes: data['notes']?.toString(),
      visitId: data['visitId']?.toString(),
      pushSent: data['pushSent'] == true,
    );
  }

  Map<String, dynamic> toFirestore({bool resetPushSent = false}) {
    return {
      'userId': userId,
      'title': title,
      'remindAt': Timestamp.fromDate(remindAt),
      if (notes != null && notes!.isNotEmpty) 'notes': notes,
      if (visitId != null && visitId!.isNotEmpty) 'visitId': visitId,
      if (resetPushSent) 'pushSent': false,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}
