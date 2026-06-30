import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/building_resident_entry.dart';

/// Backend opzionale per riepilogo AI dei risultati directory (ai.creditcore.it).
abstract final class BuildingResidentsBackendConfig {
  static const String secureHost = 'ai.creditcore.it';

  /// Quando il backend non è ancora deployato, resta disattivo senza errori.
  static const bool enabled = false;

  static String get httpUrl => 'https://$secureHost/building-residents';

  static Future<String?> summarize({
    required String address,
    required List<BuildingResidentEntry> residents,
  }) async {
    if (!enabled) return null;

    final response = await http
        .post(
          Uri.parse(httpUrl),
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode({
            'address': address,
            'residents': residents
                .map(
                  (r) => {
                    'name': r.displayName,
                    'address': r.address,
                    'phone': r.phone,
                    'source': r.sourceLabel,
                  },
                )
                .toList(),
          }),
        )
        .timeout(const Duration(seconds: 45));

    if (response.statusCode != 200) return null;

    final decoded = jsonDecode(response.body);
    final data = decoded is Map<String, dynamic>
        ? decoded
        : Map<String, dynamic>.from(decoded as Map);
    final summary = (data['summary'] ?? '').toString().trim();
    return summary.isEmpty ? null : summary;
  }
}
