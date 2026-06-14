import 'package:latlong2/latlong.dart';

import '../models/field_visit.dart';

enum RoutePlanMode {
  /// Ordine per orario programmato (e routeOrder solo a parità di orario).
  bySchedule,

  /// Ordine ottimizzato per distanza dalla posizione attuale.
  byDistance,
}

class FieldVisitRoutePlan {
  const FieldVisitRoutePlan({
    required this.orderedVisits,
    required this.mode,
    required this.usedGpsOrigin,
    this.originLatitude,
    this.originLongitude,
    this.excludedFromMaps = const [],
  });

  final List<FieldVisit> orderedVisits;
  final RoutePlanMode mode;
  final bool usedGpsOrigin;
  final double? originLatitude;
  final double? originLongitude;
  final List<FieldVisit> excludedFromMaps;
}

abstract final class FieldVisitRouteOptimizer {
  static const _distance = Distance();
  static const _maxGoogleStops = 10;

  static double distanceKm(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    return _distance.as(
      LengthUnit.Kilometer,
      LatLng(lat1, lon1),
      LatLng(lat2, lon2),
    );
  }

  static List<FieldVisit> optimizeNearestNeighbor(
    List<FieldVisit> visits, {
    required double startLat,
    required double startLng,
  }) {
    final geolocated = visits.where((v) => v.hasCoordinates).toList();
    if (geolocated.isEmpty) return _appendAddressOnlyTail(visits, const []);

    final remaining = List<FieldVisit>.from(geolocated);
    final ordered = <FieldVisit>[];
    var currentLat = startLat;
    var currentLng = startLng;

    while (remaining.isNotEmpty) {
      FieldVisit? nearest;
      var nearestDistance = double.infinity;

      for (final visit in remaining) {
        final km = distanceKm(
          currentLat,
          currentLng,
          visit.latitude!,
          visit.longitude!,
        );
        if (km < nearestDistance) {
          nearestDistance = km;
          nearest = visit;
        }
      }

      if (nearest == null) break;
      remaining.remove(nearest);
      ordered.add(nearest);
      currentLat = nearest.latitude!;
      currentLng = nearest.longitude!;
    }

    return _appendAddressOnlyTail(visits, ordered);
  }

  static List<FieldVisit> _appendAddressOnlyTail(
    List<FieldVisit> source,
    List<FieldVisit> ordered,
  ) {
    final orderedIds = ordered.map((v) => v.id).toSet();
    final tail = source
        .where(
          (v) =>
              !orderedIds.contains(v.id) &&
              v.address.trim().isNotEmpty &&
              v.isActiveForItinerary,
        )
        .toList()
      ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
    return [...ordered, ...tail];
  }

  static List<FieldVisit> orderBySchedule(List<FieldVisit> visits) {
    final routable = visits
        .where((v) => v.isActiveForItinerary)
        .where((v) => v.hasCoordinates || v.address.trim().isNotEmpty)
        .toList()
      ..sort((a, b) {
        final timeCompare = a.scheduledAt.compareTo(b.scheduledAt);
        if (timeCompare != 0) return timeCompare;
        final orderA = a.routeOrder ?? 9999;
        final orderB = b.routeOrder ?? 9999;
        return orderA.compareTo(orderB);
      });
    return routable;
  }

  static FieldVisitRoutePlan buildPlan(
    List<FieldVisit> visits, {
    required RoutePlanMode mode,
    double? originLatitude,
    double? originLongitude,
  }) {
    final routable = visits
        .where((v) => v.isActiveForItinerary)
        .where((v) => v.hasCoordinates || v.address.trim().isNotEmpty)
        .toList();

    final hasOrigin =
        originLatitude != null &&
        originLongitude != null &&
        originLatitude.abs() > 0.0001 &&
        originLongitude.abs() > 0.0001;

    List<FieldVisit> ordered;
    if (mode == RoutePlanMode.bySchedule) {
      ordered = orderBySchedule(routable);
    } else if (hasOrigin && routable.any((v) => v.hasCoordinates)) {
      ordered = optimizeNearestNeighbor(
        routable,
        startLat: originLatitude,
        startLng: originLongitude,
      );
    } else {
      ordered = orderBySchedule(routable);
    }

    final included = ordered.take(_maxGoogleStops).toList();
    final excluded = ordered.length > _maxGoogleStops
        ? ordered.sublist(_maxGoogleStops)
        : const <FieldVisit>[];

    final usedGpsOrigin =
        mode == RoutePlanMode.byDistance && hasOrigin && ordered.isNotEmpty;

    return FieldVisitRoutePlan(
      orderedVisits: included,
      mode: mode,
      usedGpsOrigin: usedGpsOrigin,
      originLatitude: originLatitude,
      originLongitude: originLongitude,
      excludedFromMaps: excluded,
    );
  }

  static double? distanceFromPreviousKm(
    FieldVisitRoutePlan plan,
    int index,
  ) {
    if (index <= 0 || index >= plan.orderedVisits.length) return null;

    final visit = plan.orderedVisits[index];
    if (!visit.hasCoordinates) return null;

    double lat;
    double lng;
    if (index == 0 && plan.usedGpsOrigin) {
      lat = plan.originLatitude!;
      lng = plan.originLongitude!;
    } else {
      final previous = plan.orderedVisits[index - 1];
      if (!previous.hasCoordinates) return null;
      lat = previous.latitude!;
      lng = previous.longitude!;
    }

    return distanceKm(lat, lng, visit.latitude!, visit.longitude!);
  }
}
