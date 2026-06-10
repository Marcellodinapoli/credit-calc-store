import 'dart:convert';

import 'package:http/http.dart' as http;

/// Geocoding gratuito via OpenStreetMap Nominatim (1 req/s).
class GeocodingService {
  static const _userAgent = 'CreditCalc/1.0 visit-itinerary';

  Future<({double lat, double lng})?> geocodeAddress(String address) async {
    final query = address.trim();
    if (query.isEmpty) return null;

    final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
      'q': query,
      'format': 'json',
      'limit': '1',
      'countrycodes': 'it',
    });

    final response = await http.get(
      uri,
      headers: {'User-Agent': _userAgent},
    );
    if (response.statusCode != 200) return null;

    final list = jsonDecode(response.body);
    if (list is! List || list.isEmpty) return null;

    final first = list.first;
    if (first is! Map<String, dynamic>) return null;

    final lat = double.tryParse(first['lat']?.toString() ?? '');
    final lon = double.tryParse(first['lon']?.toString() ?? '');
    if (lat == null || lon == null) return null;
    return (lat: lat, lng: lon);
  }
}
