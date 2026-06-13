import 'package:url_launcher/url_launcher.dart';

import '../models/field_visit.dart';

abstract final class FieldVisitMapsUtil {
  static const _maxGoogleStops = 10;

  static List<FieldVisit> routableVisits(List<FieldVisit> visits) {
    return visits
        .where((v) => v.status != FieldVisitStatus.cancelled)
        .where((v) => v.hasCoordinates || v.address.trim().isNotEmpty)
        .toList();
  }

  static String point(FieldVisit v) {
    if (v.hasCoordinates) {
      return '${v.latitude},${v.longitude}';
    }
    return Uri.encodeComponent(v.address.trim());
  }

  static String? googleMapsDayRouteUrl(
    List<FieldVisit> visits, {
    double? originLatitude,
    double? originLongitude,
  }) {
    final stops = routableVisits(visits).take(_maxGoogleStops).toList();
    if (stops.isEmpty) return null;

    final hasGpsOrigin = originLatitude != null &&
        originLongitude != null &&
        originLatitude.abs() > 0.0001 &&
        originLongitude.abs() > 0.0001;

    if (stops.length < 2 && !hasGpsOrigin) return null;

    final origin = hasGpsOrigin
        ? '$originLatitude,$originLongitude'
        : point(stops.first);

    if (stops.length == 1) {
      return 'https://www.google.com/maps/dir/?api=1'
          '&origin=$origin&destination=${point(stops.first)}&travelmode=driving';
    }

    final destination = point(stops.last);
    if (stops.length == 2) {
      if (hasGpsOrigin) {
        return 'https://www.google.com/maps/dir/?api=1'
            '&origin=$origin&destination=${point(stops.last)}'
            '&waypoints=${point(stops.first)}&travelmode=driving';
      }
      return 'https://www.google.com/maps/dir/?api=1'
          '&origin=$origin&destination=$destination&travelmode=driving';
    }

    final waypointStops = hasGpsOrigin
        ? stops.sublist(0, stops.length - 1)
        : stops.sublist(1, stops.length - 1);
    final waypoints = waypointStops.map(point).join('%7C');

    return 'https://www.google.com/maps/dir/?api=1'
        '&origin=$origin&destination=$destination'
        '&waypoints=$waypoints&travelmode=driving';
  }

  static Future<bool> openDayRoute(
    List<FieldVisit> visits, {
    double? originLatitude,
    double? originLongitude,
  }) async {
    final url = googleMapsDayRouteUrl(
      visits,
      originLatitude: originLatitude,
      originLongitude: originLongitude,
    );
    if (url == null) return false;
    final uri = Uri.parse(url);
    if (!await canLaunchUrl(uri)) return false;
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
