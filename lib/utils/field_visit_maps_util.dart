import 'package:url_launcher/url_launcher.dart';

import '../models/field_visit.dart';

abstract final class FieldVisitMapsUtil {
  static List<FieldVisit> routableVisits(List<FieldVisit> visits) {
    return visits
        .where((v) => v.status != FieldVisitStatus.cancelled)
        .where((v) => v.hasCoordinates || v.address.trim().isNotEmpty)
        .toList();
  }

  static String? googleMapsDayRouteUrl(List<FieldVisit> visits) {
    final stops = routableVisits(visits);
    if (stops.length < 2) return null;

    String point(FieldVisit v) {
      if (v.hasCoordinates) {
        return '${v.latitude},${v.longitude}';
      }
      return Uri.encodeComponent(v.address.trim());
    }

    final origin = point(stops.first);
    final destination = point(stops.last);
    if (stops.length == 2) {
      return 'https://www.google.com/maps/dir/?api=1'
          '&origin=$origin&destination=$destination&travelmode=driving';
    }

    final waypoints =
        stops.sublist(1, stops.length - 1).map(point).join('%7C');
    return 'https://www.google.com/maps/dir/?api=1'
        '&origin=$origin&destination=$destination'
        '&waypoints=$waypoints&travelmode=driving';
  }

  static Future<bool> openDayRoute(List<FieldVisit> visits) async {
    final url = googleMapsDayRouteUrl(visits);
    if (url == null) return false;
    final uri = Uri.parse(url);
    if (!await canLaunchUrl(uri)) return false;
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
