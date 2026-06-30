import 'package:cloud_firestore/cloud_firestore.dart';

import '../offline/utils/firestore_json_codec.dart';
import '../utils/itinerary_date_time.dart';

enum FieldVisitStatus { planned, completed, cancelled }

FieldVisitStatus fieldVisitStatusFrom(String? raw) {
  switch ((raw ?? '').toLowerCase()) {
    case 'completed':
      return FieldVisitStatus.completed;
    case 'cancelled':
      return FieldVisitStatus.cancelled;
    default:
      return FieldVisitStatus.planned;
  }
}

String fieldVisitStatusLabel(FieldVisitStatus status) {
  switch (status) {
    case FieldVisitStatus.planned:
      return 'In programma';
    case FieldVisitStatus.completed:
      return 'Completata';
    case FieldVisitStatus.cancelled:
      return 'Annullata';
  }
}

class FieldVisit {
  const FieldVisit({
    required this.id,
    required this.userId,
    required this.companyName,
    required this.address,
    required this.scheduledAt,
    required this.status,
    this.latitude,
    this.longitude,
    this.creditorId,
    this.creditorName,
    this.calculationId,
    this.notes,
    this.routeOrder,
  });

  final String id;
  final String userId;
  final String companyName;
  final String address;
  final DateTime scheduledAt;
  final FieldVisitStatus status;
  final double? latitude;
  final double? longitude;
  final String? creditorId;
  final String? creditorName;
  final String? calculationId;
  final String? notes;
  final int? routeOrder;

  bool get hasCoordinates =>
      latitude != null &&
      longitude != null &&
      latitude!.abs() > 0.0001 &&
      longitude!.abs() > 0.0001;

  bool get needsGeocoding => address.trim().isNotEmpty && !hasCoordinates;

  /// Visita ancora da fare su mappa e percorso (non completata/annullata).
  bool get isActiveForItinerary => status == FieldVisitStatus.planned;

  factory FieldVisit.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    return FieldVisit.fromMap(doc.id, doc.data() ?? {});
  }

  factory FieldVisit.fromMap(String id, Map<String, dynamic> data) {
    final normalized = FirestoreJsonCodec.decodeMap(
      Map<String, dynamic>.from(data),
    );
    return FieldVisit(
      id: id,
      userId: (normalized['userId'] ?? '').toString(),
      companyName: (normalized['companyName'] ?? '').toString().trim(),
      address: (normalized['address'] ?? '').toString().trim(),
      scheduledAt: _readDateTime(
        normalized,
        data,
        'scheduledAt',
        recordId: id,
      ),
      status: fieldVisitStatusFrom(normalized['status'] as String?),
      latitude: _asDouble(normalized['latitude']),
      longitude: _asDouble(normalized['longitude']),
      creditorId: normalized['creditorId']?.toString(),
      creditorName: normalized['creditorName']?.toString(),
      calculationId: normalized['calculationId']?.toString(),
      notes: normalized['notes']?.toString(),
      routeOrder: normalized['routeOrder'] is num
          ? (normalized['routeOrder'] as num).toInt()
          : null,
    );
  }

  Map<String, dynamic> toStoredMap({DateTime? updatedAt}) {
    final now = updatedAt ?? DateTime.now();
    return {
      'userId': userId,
      'companyName': companyName,
      'address': address,
      'scheduledAt': Timestamp.fromDate(scheduledAt),
      'scheduledAtMs': scheduledAt.millisecondsSinceEpoch,
      'status': status.name,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (creditorId != null && creditorId!.isNotEmpty) 'creditorId': creditorId,
      if (creditorName != null && creditorName!.isNotEmpty)
        'creditorName': creditorName,
      if (calculationId != null && calculationId!.isNotEmpty)
        'calculationId': calculationId,
      if (notes != null && notes!.isNotEmpty) 'notes': notes,
      if (routeOrder != null) 'routeOrder': routeOrder,
      'updatedAt': Timestamp.fromDate(now),
    };
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'companyName': companyName,
      'address': address,
      'scheduledAt': Timestamp.fromDate(scheduledAt),
      'status': status.name,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (creditorId != null && creditorId!.isNotEmpty) 'creditorId': creditorId,
      if (creditorName != null && creditorName!.isNotEmpty)
        'creditorName': creditorName,
      if (calculationId != null && calculationId!.isNotEmpty)
        'calculationId': calculationId,
      if (notes != null && notes!.isNotEmpty) 'notes': notes,
      if (routeOrder != null) 'routeOrder': routeOrder,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  static double? _asDouble(dynamic raw) {
    if (raw is num) return raw.toDouble();
    return double.tryParse(raw?.toString().replaceAll(',', '.') ?? '');
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
