import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../models/building_resident_entry.dart';
import 'directory_html_utils.dart';
import 'italia_online_listing_parser.dart';

/// Ricerca su Pagine Bianche (elenchi telefonici pubblici).
abstract final class PagineBiancheDirectoryService {
  static Future<List<BuildingResidentEntry>> searchByAddress(
    String address, {
    required String tab,
  }) async {
    final query = address.trim();
    if (query.length < 5) return [];

    final uri = Uri.https(
      'www.paginebianche.it',
      '/ricerca',
      {'qs': query, 'tab': tab},
    );

    try {
      final response = await http.get(
        uri,
        headers: const {'User-Agent': DirectoryHtmlUtils.userAgent},
      ).timeout(const Duration(seconds: 25));

      if (response.statusCode != 200) return [];

      final body = utf8.decode(response.bodyBytes, allowMalformed: true);
      return ItaliaOnlineListingParser.parseListings(
        html: body,
        source: 'paginebianche_$tab',
        queryAddress: query,
      );
    } catch (e, st) {
      debugPrint('PagineBiancheDirectoryService: $e\n$st');
      return [];
    }
  }
}
