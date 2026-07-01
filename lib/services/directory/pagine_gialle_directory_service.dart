import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../models/building_resident_entry.dart';
import '../../utils/building_residents_address_util.dart';
import 'directory_html_utils.dart';
import 'pagine_gialle_listing_parser.dart';

/// Ricerca su Pagine Gialle (migliore per attività a un civico).
abstract final class PagineGialleDirectoryService {
  static Future<List<BuildingResidentEntry>> searchByAddress(
    String address,
  ) async {
    final query = address.trim();
    if (query.length < 5) return [];

    final uri = _searchUri(query);

    try {
      final response = await http.get(
        uri,
        headers: const {'User-Agent': DirectoryHtmlUtils.userAgent},
      ).timeout(const Duration(seconds: 25));

      if (response.statusCode != 200) return [];

      final body = utf8.decode(response.bodyBytes, allowMalformed: true);
      final listings = PagineGialleListingParser.parseListings(body);
      return listings
          .where(
            (entry) => BuildingResidentsAddressUtil.matchesListingAddress(
              query,
              entry.address,
              extraText: entry.category,
            ),
          )
          .toList();
    } catch (e, st) {
      debugPrint('PagineGialleDirectoryService: $e\n$st');
      return [];
    }
  }

  static Uri searchUri(String address) => _searchUri(address.trim());

  static Uri _searchUri(String query) {
    final parts = BuildingResidentsAddressUtil.splitForDirectorySearch(query);
    final street = parts.streetQuery.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (parts.cityQuery != null && parts.cityQuery!.isNotEmpty) {
      return Uri.https(
        'www.paginegialle.it',
        '/ricerca/${Uri.encodeComponent(street)}/${Uri.encodeComponent(parts.cityQuery!)}',
      );
    }
    return Uri.https(
      'www.paginegialle.it',
      '/ricerca/${Uri.encodeComponent(query)}',
    );
  }
}
