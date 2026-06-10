import 'dart:math' as math;

class LatLng {
  const LatLng(this.latitude, this.longitude);

  final double latitude;
  final double longitude;
}

/// Ordina le tappe minimizzando la distanza totale (nearest-neighbor + 2-opt).
abstract final class RouteOptimizer {
  static double distanceKm(LatLng a, LatLng b) {
    const earthRadiusKm = 6371.0;
    final dLat = _toRad(b.latitude - a.latitude);
    final dLon = _toRad(b.longitude - a.longitude);
    final lat1 = _toRad(a.latitude);
    final lat2 = _toRad(b.latitude);

    final h = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1) *
            math.cos(lat2) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    return 2 * earthRadiusKm * math.asin(math.sqrt(h));
  }

  static double _toRad(double deg) => deg * math.pi / 180;

  static double totalDistanceKm({
    required LatLng start,
    required List<LatLng> stops,
    required List<int> order,
  }) {
    if (order.isEmpty) return 0;
    var total = 0.0;
    var previous = start;
    for (final index in order) {
      total += distanceKm(previous, stops[index]);
      previous = stops[index];
    }
    return total;
  }

  static List<int> optimize({
    required LatLng start,
    required List<LatLng> stops,
  }) {
    if (stops.isEmpty) return const [];
    if (stops.length == 1) return const [0];

    var order = _nearestNeighbor(start, stops);
    order = _twoOpt(start, stops, order);
    return order;
  }

  static List<int> _nearestNeighbor(LatLng start, List<LatLng> stops) {
    final remaining = List<int>.generate(stops.length, (i) => i);
    final order = <int>[];
    var current = start;

    while (remaining.isNotEmpty) {
      var bestIndex = 0;
      var bestDistance = double.infinity;
      for (var i = 0; i < remaining.length; i++) {
        final d = distanceKm(current, stops[remaining[i]]);
        if (d < bestDistance) {
          bestDistance = d;
          bestIndex = i;
        }
      }
      final next = remaining.removeAt(bestIndex);
      order.add(next);
      current = stops[next];
    }
    return order;
  }

  static List<int> _twoOpt(LatLng start, List<LatLng> stops, List<int> order) {
    if (order.length < 3) return order;

    var improved = true;
    var current = List<int>.from(order);

    while (improved) {
      improved = false;
      for (var i = 0; i < current.length - 1; i++) {
        for (var k = i + 1; k < current.length; k++) {
          final delta = _twoOptDelta(start, stops, current, i, k);
          if (delta < -1e-6) {
            _reverseSegment(current, i + 1, k);
            improved = true;
          }
        }
      }
    }
    return current;
  }

  static double _twoOptDelta(
    LatLng start,
    List<LatLng> stops,
    List<int> order,
    int i,
    int k,
  ) {
    LatLng node(int pos) => pos < 0 ? start : stops[order[pos]];

    final a = node(i - 1);
    final b = node(i);
    final c = node(k);
    final d = k + 1 < order.length ? node(k + 1) : node(-1);

    final before = distanceKm(a, b) + distanceKm(c, d);
    final after = distanceKm(a, c) + distanceKm(b, d);
    return after - before;
  }

  static void _reverseSegment(List<int> order, int from, int to) {
    while (from < to) {
      final tmp = order[from];
      order[from] = order[to];
      order[to] = tmp;
      from++;
      to--;
    }
  }
}
