import 'package:cloud_firestore/cloud_firestore.dart';

import '../offline/utils/firestore_json_codec.dart';
import '../utils/itinerary_date_time.dart';

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
    return FieldActivity.fromMap(doc.id, doc.data() ?? {});
  }

  factory FieldActivity.fromMap(String id, Map<String, dynamic> data) {
    final normalized = FirestoreJsonCodec.decodeMap(
      Map<String, dynamic>.from(data),
    );
    return FieldActivity(
      id: id,
      userId: (normalized['userId'] ?? '').toString(),
      title: (normalized['title'] ?? '').toString().trim(),
      completed: normalized['completed'] == true,
      notes: normalized['notes']?.toString(),
      dueAt: _readOptionalDateTime(normalized, data, 'dueAt'),
      visitId: normalized['visitId']?.toString(),
      recurrenceDays: normalized['recurrenceDays'] is num
          ? (normalized['recurrenceDays'] as num).toInt()
          : int.tryParse(normalized['recurrenceDays']?.toString() ?? ''),
    );
  }

  Map<String, dynamic> toStoredMap({DateTime? updatedAt}) {
    final now = updatedAt ?? DateTime.now();
    return {
      'userId': userId,
      'title': title,
      'completed': completed,
      if (notes != null && notes!.isNotEmpty) 'notes': notes,
      if (dueAt != null) ...{
        'dueAt': Timestamp.fromDate(dueAt!),
        'dueAtMs': dueAt!.millisecondsSinceEpoch,
      },
      if (visitId != null && visitId!.isNotEmpty) 'visitId': visitId,
      if (recurrenceDays != null && recurrenceDays! > 0)
        'recurrenceDays': recurrenceDays,
      'updatedAt': Timestamp.fromDate(now),
    };
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

  static DateTime? _readOptionalDateTime(
    Map<String, dynamic> normalized,
    Map<String, dynamic> raw,
    String field,
  ) {
    final msField = '${field}Ms';
    final ms = normalized[msField] ?? raw[msField];
    if (ms is num) {
      return DateTime.fromMillisecondsSinceEpoch(ms.toInt(), isUtc: true).toLocal();
    }
    return ItineraryDateTime.parseStored(normalized[field]) ??
        ItineraryDateTime.parseStored(raw[field]);
  }
}
