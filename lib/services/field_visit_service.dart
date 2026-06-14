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

  static String visitDayKeyId(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';

  static Map<String, int> visitCountsByDayId(
    List<FieldVisit> visits, {
    bool excludeCancelled = true,
  }) {
    final counts = <String, int>{};
    for (final visit in visits) {
      if (excludeCancelled && visit.status == FieldVisitStatus.cancelled) {
        continue;
      }
      final key = visitDayKeyId(visit.scheduledAt);
      counts[key] = (counts[key] ?? 0) + 1;
    }
    return counts;
  }

  static List<FieldVisit> _filterAndSortForDay(
    List<FieldVisit> visits,
    DateTime day,
  ) {
    final start = _dayStart(day);
    final end = _dayEnd(day);
    final filtered = visits
        .where(
          (v) =>
              !v.scheduledAt.isBefore(start) && v.scheduledAt.isBefore(end),
        )
        .toList();
    filtered.sort((a, b) {
      final orderA = a.routeOrder ?? 9999;
      final orderB = b.routeOrder ?? 9999;
      if (orderA != orderB) return orderA.compareTo(orderB);
      return a.scheduledAt.compareTo(b.scheduledAt);
    });
    return filtered;
  }

  static Stream<List<FieldVisit>> watchForDay(DateTime day) {
    return watchAllForUser().map((visits) => _filterAndSortForDay(visits, day));
  }

  static Stream<List<FieldVisit>> watchWithCoordinates({DateTime? day}) {
    return watchAllForUser().map((all) {
      Iterable<FieldVisit> visits = all.where(
        (v) => v.hasCoordinates && v.isActiveForItinerary,
      );
      if (day != null) {
        visits = _filterAndSortForDay(all, day).where(
          (v) => v.hasCoordinates && v.isActiveForItinerary,
        );
      }
      final list = visits.toList();
      if (day == null) {
        list.sort((a, b) {
          final orderA = a.routeOrder ?? 9999;
          final orderB = b.routeOrder ?? 9999;
          if (orderA != orderB) return orderA.compareTo(orderB);
          return a.scheduledAt.compareTo(b.scheduledAt);
        });
      }
      return list;
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
      try {
        resolvedAddress = (await CreditorVisitAddressService.lookupAddress(
              creditorId: creditorId,
            )) ??
            '';
      } catch (_) {
        resolvedAddress = '';
      }
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
