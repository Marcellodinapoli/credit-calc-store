import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../models/building_resident_entry.dart';
import 'directory_html_utils.dart';
import 'italia_online_listing_parser.dart';

/// Ricerca su portali ItaliaOnline (Pagine Bianche, 1188, Elenchi telefonici, …).
abstract final class ItaliaOnlineDirectoryService {
  static Future<List<BuildingResidentEntry>> searchByAddress(
    String address, {
    required String host,
    required String source,
    required String tab,
  }) async {
    final query = address.trim();
    if (query.length < 5) return [];

    final uri = Uri.https(
      host,
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
        source: source,
        queryAddress: query,
      );
    } catch (e, st) {
      debugPrint('ItaliaOnlineDirectoryService($host/$tab): $e\n$st');
      return [];
    }
  }
}
