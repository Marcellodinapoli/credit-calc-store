import '../core/firestore_user_scope.dart';
import '../models/field_visit.dart';
import '../utils/itinerary_date_time.dart';
import 'creditor_visit_address_service.dart';
import 'field_visit_notification_service.dart';
import 'geocoding_service.dart';
import 'itinerary_storage.dart';
import 'itinerary_storage_access.dart';
import 'practice_data_propagation_service.dart';

abstract final class FieldVisitService {
  static ItineraryStorage get _storage => ItineraryStorageAccess.instance;

  static bool _isSameLocalDay(DateTime a, DateTime day) =>
      ItineraryDateTime.isSameCalendarDay(a, day);

  static DateTime localDayKey(DateTime value) =>
      ItineraryDateTime.calendarDay(value);

  static String visitDayKeyId(DateTime value) {
    final day = ItineraryDateTime.calendarDay(value);
    return '${day.year.toString().padLeft(4, '0')}-'
        '${day.month.toString().padLeft(2, '0')}-'
        '${day.day.toString().padLeft(2, '0')}';
  }

  static bool hasAppointmentAt(
    List<FieldVisit> visits,
    DateTime scheduledAt, {
    String? excludeVisitId,
  }) {
    for (final visit in visits) {
      if (visit.status == FieldVisitStatus.cancelled) continue;
      if (excludeVisitId != null &&
          excludeVisitId.isNotEmpty &&
          visit.id == excludeVisitId) {
        continue;
      }
      final existing = visit.scheduledAt;
      if (existing.year == scheduledAt.year &&
          existing.month == scheduledAt.month &&
          existing.day == scheduledAt.day &&
          existing.hour == scheduledAt.hour &&
          existing.minute == scheduledAt.minute) {
        return true;
      }
    }
    return false;
  }

  static Future<bool> hasConflictingAppointment(
    DateTime scheduledAt, {
    String? excludeVisitId,
  }) async {
    final visits = await _storage.fetchAllVisits();
    return hasAppointmentAt(
      visits,
      scheduledAt,
      excludeVisitId: excludeVisitId,
    );
  }

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
    final filtered =
        visits.where((v) => _isSameLocalDay(v.scheduledAt, day)).toList();
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
    bool skipPracticePropagation = false,
  }) async {
    final userId = FirestoreUserScope.uid;
    if (userId == null) {
      throw StateError('Utente non autenticato');
    }

    FieldVisit? previousVisit;
    if (!skipPracticePropagation && id != null && id.isNotEmpty) {
      final existingVisits = await _storage.fetchAllVisits();
      for (final visit in existingVisits) {
        if (visit.id == id) {
          previousVisit = visit;
          break;
        }
      }
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

    final isNew = id == null || id.isEmpty;
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

    final savedId = await _storage.saveVisit(
      id: id,
      visit: visit,
      isNew: isNew,
      includePreVisitPushReset: isNew,
    );

    await FieldVisitNotificationService.cancelForVisit(savedId);
    if (status == FieldVisitStatus.planned) {
      await FieldVisitNotificationService.scheduleIfEnabled(
        FieldVisit(
          id: savedId,
          userId: userId,
          companyName: visit.companyName,
          address: visit.address,
          scheduledAt: visit.scheduledAt,
          status: visit.status,
          latitude: visit.latitude,
          longitude: visit.longitude,
          creditorId: visit.creditorId,
          creditorName: visit.creditorName,
          calculationId: visit.calculationId,
          notes: visit.notes,
          routeOrder: visit.routeOrder,
        ),
      );
    }

    if (!skipPracticePropagation) {
      await PracticeDataPropagationService.afterFieldVisitSaved(
        visit: FieldVisit(
          id: savedId,
          userId: userId,
          companyName: visit.companyName,
          address: visit.address,
          scheduledAt: visit.scheduledAt,
          status: visit.status,
          latitude: visit.latitude,
          longitude: visit.longitude,
          creditorId: visit.creditorId,
          creditorName: visit.creditorName,
          calculationId: visit.calculationId,
          notes: visit.notes,
          routeOrder: visit.routeOrder,
        ),
        previous: previousVisit,
      );
    }

    return savedId;
  }

  static Future<void> delete(String id) async {
    await FieldVisitNotificationService.cancelForVisit(id);
    await _storage.deleteVisit(id);
  }

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

  static Stream<List<FieldVisit>> watchAllForUser() => _storage.watchAllVisits();

  static Future<List<FieldVisit>> fetchAllForUser() =>
      _storage.fetchAllVisits();

  static Future<List<FieldVisit>> fetchAllForUserId(String userId) async {
    final current = FirestoreUserScope.uid;
    if (current == userId) return fetchAllForUser();
    return const [];
  }

  static Future<void> updateStatus(String id, FieldVisitStatus status) async {
    await _storage.updateVisitStatus(id, status);

    if (status != FieldVisitStatus.planned) {
      await FieldVisitNotificationService.cancelForVisit(id);
      return;
    }

    final visits = await _storage.fetchAllVisits();
    for (final visit in visits) {
      if (visit.id != id) continue;
      await FieldVisitNotificationService.scheduleIfEnabled(visit);
      break;
    }
  }

  static Future<void> saveRouteOrder(List<FieldVisit> ordered) {
    return _storage.saveVisitRouteOrder(ordered);
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
