import 'package:cloud_firestore/cloud_firestore.dart';

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
    final data = doc.data() ?? {};
    final scheduled = data['scheduledAt'];
    return FieldVisit(
      id: doc.id,
      userId: (data['userId'] ?? '').toString(),
      companyName: (data['companyName'] ?? '').toString().trim(),
      address: (data['address'] ?? '').toString().trim(),
      scheduledAt: scheduled is Timestamp
          ? scheduled.toDate()
          : DateTime.now(),
      status: fieldVisitStatusFrom(data['status'] as String?),
      latitude: _asDouble(data['latitude']),
      longitude: _asDouble(data['longitude']),
      creditorId: data['creditorId']?.toString(),
      creditorName: data['creditorName']?.toString(),
      calculationId: data['calculationId']?.toString(),
      notes: data['notes']?.toString(),
      routeOrder: data['routeOrder'] is int ? data['routeOrder'] as int : null,
    );
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
}
