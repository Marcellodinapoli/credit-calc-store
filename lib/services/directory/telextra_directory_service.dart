import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../utils/directory_web_uri_util.dart';
import '../../config/telextra_directory_config.dart';
import '../../models/building_resident_entry.dart';
import 'duckduckgo_web_search_service.dart';
import 'italia_online_directory_service.dart';

/// Ricerca nominativi tramite Telextra (backend) e portali elenchi collegati.
abstract final class TelextraDirectoryService {
  static Future<List<BuildingResidentEntry>> searchAddress(
    String address,
  ) async {
    final query = address.trim();
    if (query.length < 5) return [];

    final futures = <Future<List<BuildingResidentEntry>>>[
      _searchBackend(query),
      _searchWebDirectories(query),
      _searchDuckDuckGo(query),
    ];

    final batches = await Future.wait(futures);
    return batches.expand((batch) => batch).toList();
  }

  static Future<List<BuildingResidentEntry>> _searchBackend(
    String query,
  ) async {
    if (!TelextraDirectoryConfig.backendEnabled) return [];

    try {
      final response = await http
          .post(
            Uri.parse(TelextraDirectoryConfig.searchUrl),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({'address': query}),
          )
          .timeout(const Duration(seconds: 45));

      if (response.statusCode != 200) return [];

      final decoded = jsonDecode(response.body);
      final data = decoded is Map<String, dynamic>
          ? decoded
          : Map<String, dynamic>.from(decoded as Map);
      final residents = data['residents'];
      if (residents is! List) return [];

      final out = <BuildingResidentEntry>[];
      for (final raw in residents) {
        if (raw is! Map) continue;
        final map = raw is Map<String, dynamic>
            ? raw
            : Map<String, dynamic>.from(raw);
        final name = (map['name'] ?? map['displayName'] ?? '').toString().trim();
        final listingAddress =
            (map['address'] ?? '').toString().trim();
        if (name.isEmpty || listingAddress.isEmpty) continue;

        out.add(
          BuildingResidentEntry(
            displayName: name,
            address: listingAddress,
            source: 'telextra_backend',
            phone: (map['phone'] ?? '').toString().trim().isEmpty
                ? null
                : (map['phone'] ?? '').toString().trim(),
            category: (map['category'] ?? '').toString().trim().isEmpty
                ? null
                : (map['category'] ?? '').toString().trim(),
          ),
        );
      }
      return out;
    } catch (e, st) {
      debugPrint('TelextraDirectoryService backend: $e\n$st');
      return [];
    }
  }

  static Future<List<BuildingResidentEntry>> _searchWebDirectories(
    String query,
  ) async {
    final futures = <Future<List<BuildingResidentEntry>>>[];
    for (final host in TelextraDirectoryConfig.webHosts) {
      final hostKey = host.replaceAll('www.', '').split('.').first;
      for (final tab in TelextraDirectoryConfig.webTabs) {
        futures.add(
          ItaliaOnlineDirectoryService.searchByAddress(
            query,
            host: host,
            source: 'telextra_${hostKey}_$tab',
            tab: tab,
          ),
        );
      }
    }
    final batches = await Future.wait(futures);
    return batches.expand((batch) => batch).toList();
  }

  static Future<List<BuildingResidentEntry>> _searchDuckDuckGo(
    String query,
  ) async {
    final queries = [
      'site:1188.it $query',
      'site:elenchitelefonici.it $query',
      'site:telextra.it $query telefono',
      '"$query" telextra telefono',
    ];

    final out = <BuildingResidentEntry>[];
    for (final searchQuery in queries) {
      try {
        final hits = await DuckDuckGoWebSearchService.searchRawQuery(
          searchQuery,
          query,
          source: 'telextra_ddg',
        );
        out.addAll(hits);
      } catch (e, st) {
        debugPrint('TelextraDirectoryService DDG: $e\n$st');
      }
    }
    return out;
  }

  static Uri webSearchUri(String address) {
    return DirectoryWebUriUtil.italiaOnlineRicerca(
      'www.1188.it',
      address,
      tab: 'indirizzo',
    );
  }
}
