import 'package:latlong2/latlong.dart';

import '../models/field_visit.dart';

class MapMarkerCluster {
  const MapMarkerCluster({
    required this.center,
    required this.visits,
  });

  final LatLng center;
  final List<FieldVisit> visits;

  bool get isSingle => visits.length == 1;
  int get count => visits.length;
}

List<MapMarkerCluster> clusterFieldVisits(
  List<FieldVisit> visits, {
  required double zoom,
  int clusterThreshold = 8,
}) {
  if (visits.isEmpty) return const [];

  if (visits.length < clusterThreshold || zoom >= 12) {
    return visits
        .map(
          (v) => MapMarkerCluster(
            center: LatLng(v.latitude!, v.longitude!),
            visits: [v],
          ),
        )
        .toList();
  }

  final cellDegrees = zoom < 9 ? 0.12 : zoom < 11 ? 0.06 : 0.03;
  final buckets = <String, List<FieldVisit>>{};

  for (final visit in visits) {
    final lat = visit.latitude!;
    final lng = visit.longitude!;
    final latKey = (lat / cellDegrees).floor();
    final lngKey = (lng / cellDegrees).floor();
    final key = '$latKey:$lngKey';
    buckets.putIfAbsent(key, () => []).add(visit);
  }

  return buckets.values.map((group) {
    final lat =
        group.map((v) => v.latitude!).reduce((a, b) => a + b) / group.length;
    final lng =
        group.map((v) => v.longitude!).reduce((a, b) => a + b) / group.length;
    return MapMarkerCluster(
      center: LatLng(lat, lng),
      visits: group,
    );
  }).toList();
}
