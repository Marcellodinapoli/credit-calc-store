import 'dart:convert';

import 'package:http/http.dart' as http;

/// Geocoding leggero via OpenStreetMap Nominatim (senza API key).
abstract final class GeocodingService {
  static Future<({double lat, double lng})?> lookupAddress(String address) async {
    final query = address.trim();
    if (query.length < 4) return null;

    final uri = Uri.https(
      'nominatim.openstreetmap.org',
      '/search',
      {
        'q': query,
        'format': 'json',
        'limit': '1',
        'countrycodes': 'it',
      },
    );

    try {
      final response = await http.get(
        uri,
        headers: const {'User-Agent': 'CreditCalc/1.0 itinerary'},
      );
      if (response.statusCode != 200) return null;

      final list = jsonDecode(response.body);
      if (list is! List || list.isEmpty) return null;

      final first = list.first;
      if (first is! Map) return null;

      final lat = double.tryParse(first['lat']?.toString() ?? '');
      final lng = double.tryParse(first['lon']?.toString() ?? '');
      if (lat == null || lng == null) return null;
      return (lat: lat, lng: lng);
    } catch (_) {
      return null;
    }
  }
}
