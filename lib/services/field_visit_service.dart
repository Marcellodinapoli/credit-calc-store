import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/firestore_user_scope.dart';
import '../models/field_visit.dart';
import 'creditor_visit_address_service.dart';
import 'geocoding_service.dart';

abstract final class FieldVisitService {
  static CollectionReference<Map<String, dynamic>> get _col =>
      FirebaseFirestore.instance.collection('field_visits');

  static DateTime _dayStart(DateTime day) =>
      DateTime(day.year, day.month, day.day);

  static DateTime _dayEnd(DateTime day) =>
      _dayStart(day).add(const Duration(days: 1));

  static Stream<List<FieldVisit>> watchForDay(DateTime day) {
    final userId = FirestoreUserScope.uid;
    if (userId == null) return Stream.value(const []);

    final start = _dayStart(day);
    final end = _dayEnd(day);

    return _col
        .where('userId', isEqualTo: userId)
        .where('scheduledAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('scheduledAt', isLessThan: Timestamp.fromDate(end))
        .snapshots()
        .map((snap) {
      final visits = snap.docs.map(FieldVisit.fromDoc).toList();
      visits.sort((a, b) {
        final orderA = a.routeOrder ?? 9999;
        final orderB = b.routeOrder ?? 9999;
        if (orderA != orderB) return orderA.compareTo(orderB);
        return a.scheduledAt.compareTo(b.scheduledAt);
      });
      return visits;
    });
  }

  static Stream<List<FieldVisit>> watchWithCoordinates({DateTime? day}) {
    final userId = FirestoreUserScope.uid;
    if (userId == null) return Stream.value(const []);

    Query<Map<String, dynamic>> query =
        _col.where('userId', isEqualTo: userId);

    if (day != null) {
      final start = _dayStart(day);
      final end = _dayEnd(day);
      query = query
          .where('scheduledAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('scheduledAt', isLessThan: Timestamp.fromDate(end));
    }

    return query.snapshots().map((snap) {
      final visits = snap.docs
          .map(FieldVisit.fromDoc)
          .where((v) => v.hasCoordinates && v.status != FieldVisitStatus.cancelled)
          .toList();
      visits.sort((a, b) {
        final orderA = a.routeOrder ?? 9999;
        final orderB = b.routeOrder ?? 9999;
        if (orderA != orderB) return orderA.compareTo(orderB);
        return a.scheduledAt.compareTo(b.scheduledAt);
      });
      return visits;
    });
  }

  static Future<String> save({
    String? id,
    required String companyName,
    required String address,
    required DateTime scheduledAt,
    FieldVisitStatus status = FieldVisitStatus.planned,
    double? latitude,
    double? longitude,
    String? creditorId,
    String? creditorName,
    String? calculationId,
    String? notes,
    int? routeOrder,
    bool geocodeIfNeeded = true,
  }) async {
    final userId = FirestoreUserScope.uid;
    if (userId == null) {
      throw StateError('Utente non autenticato');
    }

    var lat = latitude;
    var lng = longitude;
    if (geocodeIfNeeded && (lat == null || lng == null) && address.trim().isNotEmpty) {
      final coords = await GeocodingService.lookupAddress(address);
      if (coords != null) {
        lat = coords.lat;
        lng = coords.lng;
      }
    }

    final visit = FieldVisit(
      id: id ?? '',
      userId: userId,
      companyName: companyName.trim(),
      address: address.trim(),
      scheduledAt: scheduledAt,
      status: status,
      latitude: lat,
      longitude: lng,
      creditorId: creditorId,
      creditorName: creditorName,
      calculationId: calculationId,
      notes: notes,
      routeOrder: routeOrder,
    );

    final data = FirestoreUserScope.withOwner({
      ...visit.toFirestore(),
      if (id == null) 'createdAt': FieldValue.serverTimestamp(),
      'preVisitPushSent': false,
    });

    if (id == null || id.isEmpty) {
      final ref = await _col.add(data);
      return ref.id;
    }

    await _col.doc(id).set(data, SetOptions(merge: true));
    return id;
  }

  static Future<void> delete(String id) => _col.doc(id).delete();

  static Future<bool> refreshGeocoding(FieldVisit visit) async {
    if (visit.address.trim().isEmpty) return false;

    final coords = await GeocodingService.lookupAddress(visit.address);
    if (coords == null) return false;

    await save(
      id: visit.id,
      companyName: visit.companyName,
      address: visit.address,
      scheduledAt: visit.scheduledAt,
      status: visit.status,
      latitude: coords.lat,
      longitude: coords.lng,
      creditorId: visit.creditorId,
      creditorName: visit.creditorName,
      calculationId: visit.calculationId,
      notes: visit.notes,
      routeOrder: visit.routeOrder,
      geocodeIfNeeded: false,
    );
    return true;
  }

  static Stream<List<FieldVisit>> watchAllForUser() {
    final userId = FirestoreUserScope.uid;
    if (userId == null) return Stream.value(const []);

    return _col.where('userId', isEqualTo: userId).snapshots().map((snap) {
      return snap.docs.map(FieldVisit.fromDoc).toList();
    });
  }

  static Future<void> updateStatus(String id, FieldVisitStatus status) {
    return _col.doc(id).update({
      'status': status.name,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> saveRouteOrder(List<FieldVisit> ordered) async {
    final batch = FirebaseFirestore.instance.batch();
    for (var i = 0; i < ordered.length; i++) {
      batch.update(_col.doc(ordered[i].id), {
        'routeOrder': i,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }

  static Future<void> importFromCalculation({
    required Map<String, dynamic> calculation,
    required String calculationId,
    required DateTime scheduledAt,
    String address = '',
  }) async {
    final creditorId = calculation['creditorId']?.toString();
    var resolvedAddress = address.trim();
    if (resolvedAddress.isEmpty) {
      resolvedAddress = (await CreditorVisitAddressService.lookupAddress(
            creditorId: creditorId,
          )) ??
          '';
    }

    await save(
      companyName: (calculation['companyName'] ?? 'Pratica').toString(),
      address: resolvedAddress,
      scheduledAt: scheduledAt,
      creditorId: creditorId,
      creditorName: calculation['creditorName']?.toString(),
      calculationId: calculationId,
    );
  }
}
