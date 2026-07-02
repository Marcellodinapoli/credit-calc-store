import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../models/building_resident_entry.dart';
import '../../utils/building_residents_address_util.dart';
import 'directory_html_utils.dart';

/// Ricerca web tramite Bing HTML (senza API key).
abstract final class BingWebSearchService {
  static Future<List<BuildingResidentEntry>> searchAddress(
    String address,
  ) async {
    final query = address.trim();
    if (query.length < 5) return [];

    final uri = Uri.https(
      'www.bing.com',
      '/search',
      {
        'q': BuildingResidentsAddressUtil.webSearchQuery(query),
        'cc': 'it',
        'setlang': 'it',
      },
    );

    try {
      final response = await http.get(
        uri,
        headers: const {'User-Agent': DirectoryHtmlUtils.userAgent},
      ).timeout(const Duration(seconds: 20));

      if (response.statusCode != 200) return [];

      final html = utf8.decode(response.bodyBytes, allowMalformed: true);
      return _parseResults(html, query);
    } catch (e, st) {
      debugPrint('BingWebSearchService: $e\n$st');
      return [];
    }
  }

  static List<BuildingResidentEntry> _parseResults(
    String html,
    String queryAddress,
  ) {
    final items = RegExp(
      r'<li class="b_algo"[^>]*>(.*?)</li>',
      dotAll: true,
    ).allMatches(html);

    final out = <BuildingResidentEntry>[];
    for (final item in items) {
      final block = item.group(1) ?? '';
      final title = DirectoryHtmlUtils.firstMatch(block, [
        RegExp(r'<h2[^>]*>\s*<a[^>]*>(.*?)</a>', dotAll: true),
      ]);
      if (title == null || title.isEmpty) continue;

      final snippet = DirectoryHtmlUtils.firstMatch(block, [
        RegExp(r'<p class="b_lineclamp\d"[^>]*>(.*?)</p>', dotAll: true),
      ]) ??
          '';

      final url = DirectoryHtmlUtils.firstMatch(block, [
        RegExp(r'<cite>(.*?)</cite>', dotAll: true),
      ]) ??
          '';

      final cleanTitle = DirectoryHtmlUtils.decodeHtmlEntities(title);
      final cleanSnippet = DirectoryHtmlUtils.decodeHtmlEntities(snippet);
      final combined = '$cleanTitle $cleanSnippet $url';

      if (!_isRelevant(queryAddress, combined, url)) continue;

      final extractedAddress = _extractAddress(combined) ??
          BuildingResidentsAddressUtil.stripCivicNumber(queryAddress);
      if (extractedAddress.isEmpty) continue;
      if (!BuildingResidentsAddressUtil.matchesListingAddress(
        queryAddress,
        extractedAddress,
        strict: false,
      )) {
        continue;
      }

      final phone =
          DirectoryHtmlUtils.extractPhone(combined)?.replaceAll(RegExp(r'\s+'), '');

      out.add(
        BuildingResidentEntry(
          displayName: cleanTitle,
          address: extractedAddress,
          source: 'bing',
          phone: phone,
          category: cleanSnippet.length > 120
              ? '${cleanSnippet.substring(0, 117)}...'
              : cleanSnippet,
        ),
      );
    }
    return out;
  }

  static bool _isRelevant(String queryAddress, String text, String url) {
    if (!DirectoryHtmlUtils.isDirectoryHost(url) &&
        !DirectoryHtmlUtils.isDirectoryHost(text)) {
      return false;
    }
    final extracted = _extractAddress(text);
    if (extracted != null) {
      return BuildingResidentsAddressUtil.matchesListingAddress(
        queryAddress,
        extracted,
        strict: false,
      );
    }
    return BuildingResidentsAddressUtil.matchesListingAddress(
      queryAddress,
      text,
      strict: false,
    );
  }

  static String? _extractAddress(String text) {
    final withCivic = RegExp(
      r'((?:Via|Viale|Piazza|Corso|Largo|Vicolo|Strada|Frazione|Località)[^.,\n]{3,80}\d+[a-zA-Z]?)',
      caseSensitive: false,
    ).firstMatch(text);
    if (withCivic != null) return withCivic.group(1)!.trim();

    final withoutCivic = RegExp(
      r'((?:Via|Viale|Piazza|Corso|Largo|Vicolo|Strada|Frazione|Località)[^.,\n]{3,60})',
      caseSensitive: false,
    ).firstMatch(text);
    return withoutCivic?.group(1)?.trim();
  }
}
