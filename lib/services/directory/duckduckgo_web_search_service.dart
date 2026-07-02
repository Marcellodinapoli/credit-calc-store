import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../models/building_resident_entry.dart';
import '../../utils/building_residents_address_util.dart';
import 'directory_html_utils.dart';

/// Ricerca web tramite DuckDuckGo HTML (senza API key).
abstract final class DuckDuckGoWebSearchService {
  static const _endpoint = 'https://html.duckduckgo.com/html/';

  static Future<List<BuildingResidentEntry>> searchAddress(
    String address,
  ) async {
    final query = address.trim();
    if (query.length < 5) return [];

    final queries = [
      '"$query" telefono',
      'site:paginebianche.it $query',
      'site:paginegialle.it $query',
      'site:1188.it $query',
      'site:virgilio.it $query telefono',
    ];

    final out = <BuildingResidentEntry>[];
    for (final q in queries) {
      try {
        out.addAll(await searchRawQuery(q, query));
      } catch (e, st) {
        debugPrint('DuckDuckGoWebSearchService: $q -> $e\n$st');
      }
    }
    return out;
  }

  static Future<List<BuildingResidentEntry>> searchRawQuery(
    String searchQuery,
    String queryAddress, {
    String source = 'duckduckgo',
  }) async {
    final hits = await _searchQuery(searchQuery, queryAddress);
    if (source == 'duckduckgo') return hits;
    return hits
        .map(
          (entry) => BuildingResidentEntry(
            displayName: entry.displayName,
            address: entry.address,
            source: source,
            phone: entry.phone,
            category: entry.category,
          ),
        )
        .toList();
  }

  static Future<List<BuildingResidentEntry>> _searchQuery(
    String searchQuery,
    String queryAddress,
  ) async {
    final response = await http
        .post(
          Uri.parse(_endpoint),
          headers: {
            'User-Agent': DirectoryHtmlUtils.userAgent,
            'Content-Type': 'application/x-www-form-urlencoded',
          },
          body: {'q': searchQuery, 'kl': 'it-it'},
        )
        .timeout(const Duration(seconds: 20));

    if (response.statusCode != 200) return [];

    final html = utf8.decode(response.bodyBytes, allowMalformed: true);
    return _parseResults(html, queryAddress);
  }

  static List<BuildingResidentEntry> _parseResults(
    String html,
    String queryAddress,
  ) {
    final blocks = RegExp(
      r'<div class="result[^"]*">(.*?)</div>\s*</div>',
      dotAll: true,
    ).allMatches(html);

    final out = <BuildingResidentEntry>[];
    for (final block in blocks) {
      final chunk = block.group(1) ?? '';
      final title = DirectoryHtmlUtils.firstMatch(chunk, [
        RegExp(r'class="result__a"[^>]*>([^<]+)'),
      ]);
      if (title == null || title.isEmpty) continue;

      final snippet = DirectoryHtmlUtils.firstMatch(chunk, [
        RegExp(r'class="result__snippet"[^>]*>([^<]+)'),
      ]) ??
          '';

      final url = DirectoryHtmlUtils.firstMatch(chunk, [
        RegExp(r'class="result__a"[^>]*href="([^"]+)"'),
      ]) ??
          '';

      final cleanTitle = DirectoryHtmlUtils.decodeHtmlEntities(title);
      final cleanSnippet = DirectoryHtmlUtils.decodeHtmlEntities(snippet);
      final combined = '$cleanTitle $cleanSnippet $url';

      if (!_isRelevant(queryAddress, combined, url)) continue;

      final extractedAddress = _extractAddress(cleanSnippet) ??
          _extractAddress(combined) ??
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
      final name = _extractDisplayName(cleanTitle, cleanSnippet);

      out.add(
        BuildingResidentEntry(
          displayName: name,
          address: extractedAddress,
          source: 'duckduckgo',
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

  static String _extractDisplayName(String title, String snippet) {
    final fromSnippet = RegExp(
      r'([A-ZÀ-Ý][a-zà-ù]+(?:\s+[A-ZÀ-Ý][a-zà-ù]+){1,3})',
    ).firstMatch(snippet);
    if (fromSnippet != null) return fromSnippet.group(1)!.trim();

    final cleaned = title
        .replaceAll(RegExp(r'\s*-\s*PagineBianche.*', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s*\|.*'), '')
        .trim();
    return cleaned.isNotEmpty ? cleaned : title;
  }

  static String? _extractAddress(String snippet) {
    final withCivic = RegExp(
      r'((?:Via|Viale|Piazza|Corso|Largo|Vicolo|Strada|Frazione|Località)[^.,\n]{3,80}\d+[a-zA-Z]?)',
      caseSensitive: false,
    ).firstMatch(snippet);
    if (withCivic != null) return withCivic.group(1)!.trim();

    final withoutCivic = RegExp(
      r'((?:Via|Viale|Piazza|Corso|Largo|Vicolo|Strada|Frazione|Località)[^.,\n]{3,60})',
      caseSensitive: false,
    ).firstMatch(snippet);
    return withoutCivic?.group(1)?.trim();
  }
}
