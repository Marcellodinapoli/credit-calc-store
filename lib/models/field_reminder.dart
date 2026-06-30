import 'package:cloud_firestore/cloud_firestore.dart';

import '../offline/utils/firestore_json_codec.dart';
import '../utils/itinerary_date_time.dart';

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
    return FieldReminder.fromMap(doc.id, doc.data() ?? {});
  }

  factory FieldReminder.fromMap(String id, Map<String, dynamic> data) {
    final normalized = FirestoreJsonCodec.decodeMap(
      Map<String, dynamic>.from(data),
    );
    return FieldReminder(
      id: id,
      userId: (normalized['userId'] ?? '').toString(),
      title: (normalized['title'] ?? '').toString().trim(),
      remindAt: _readDateTime(
        normalized,
        data,
        'remindAt',
        recordId: id,
      ),
      notes: normalized['notes']?.toString(),
      visitId: normalized['visitId']?.toString(),
      pushSent: normalized['pushSent'] == true,
    );
  }

  Map<String, dynamic> toStoredMap({
    DateTime? updatedAt,
    bool resetPushSent = false,
  }) {
    final now = updatedAt ?? DateTime.now();
    return {
      'userId': userId,
      'title': title,
      'remindAt': Timestamp.fromDate(remindAt),
      'remindAtMs': remindAt.millisecondsSinceEpoch,
      if (notes != null && notes!.isNotEmpty) 'notes': notes,
      if (visitId != null && visitId!.isNotEmpty) 'visitId': visitId,
      if (resetPushSent) 'pushSent': false,
      'updatedAt': Timestamp.fromDate(now),
    };
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

  static DateTime _readDateTime(
    Map<String, dynamic> normalized,
    Map<String, dynamic> raw,
    String field, {
    required String recordId,
  }) {
    final msField = '${field}Ms';
    final ms = normalized[msField] ?? raw[msField];
    if (ms is num) {
      return DateTime.fromMillisecondsSinceEpoch(ms.toInt(), isUtc: true).toLocal();
    }

    final parsed = ItineraryDateTime.parseStored(normalized[field]) ??
        ItineraryDateTime.parseStored(raw[field]);
    if (parsed != null) return parsed;
    throw FormatException('$field non valido per record $recordId');
  }
}
