import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../services/building_residents_lookup_service.dart';
import '../services/directory/pagine_gialle_directory_service.dart';
import '../services/directory/telextra_directory_service.dart';
import 'building_residents_address_util.dart';

/// Motore di ricerca apribile da «Ricerca per indirizzo».
class AddressSearchEngine {
  const AddressSearchEngine({
    required this.id,
    required this.label,
    required this.domain,
    this.kind = AddressSearchEngineKind.custom,
  });

  final String id;
  final String label;
  final String domain;
  final AddressSearchEngineKind kind;

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'domain': domain,
        'kind': kind.name,
      };

  factory AddressSearchEngine.fromJson(Map<String, dynamic> json) {
    final kindName = (json['kind'] ?? 'custom').toString();
    final kind = AddressSearchEngineKind.values.firstWhere(
      (value) => value.name == kindName,
      orElse: () => AddressSearchEngineKind.custom,
    );
    return AddressSearchEngine(
      id: (json['id'] ?? '').toString(),
      label: (json['label'] ?? '').toString(),
      domain: (json['domain'] ?? '').toString(),
      kind: kind,
    );
  }

  Uri buildUri(String address) {
    switch (kind) {
      case AddressSearchEngineKind.pagineBianche:
        return BuildingResidentsLookupService.pagineBiancheWebUri(address);
      case AddressSearchEngineKind.pagineGialle:
        return PagineGialleDirectoryService.searchUri(address);
      case AddressSearchEngineKind.telextra:
        return TelextraDirectoryService.webSearchUri(address);
      case AddressSearchEngineKind.bing:
        return BuildingResidentsLookupService.bingWebUri(address);
      case AddressSearchEngineKind.google:
        return BuildingResidentsLookupService.googleWebUri(address);
      case AddressSearchEngineKind.custom:
        return Uri.https(
          domain,
          '/search',
          {'q': BuildingResidentsAddressUtil.webSearchQuery(address)},
        );
    }
  }
}

enum AddressSearchEngineKind {
  pagineBianche,
  pagineGialle,
  telextra,
  bing,
  google,
  custom,
}

/// Persistenza motori di ricerca (default = elenco attuale in pagina).
abstract final class AddressSearchEnginesPrefs {
  static const _prefsKey = 'address_search_engines_v1';

  static const List<AddressSearchEngine> defaults = [
    AddressSearchEngine(
      id: 'pagine_bianche',
      label: 'Pagine Bianche (indirizzo)',
      domain: 'www.paginebianche.it',
      kind: AddressSearchEngineKind.pagineBianche,
    ),
    AddressSearchEngine(
      id: 'pagine_gialle',
      label: 'Pagine Gialle',
      domain: 'www.paginegialle.it',
      kind: AddressSearchEngineKind.pagineGialle,
    ),
    AddressSearchEngine(
      id: 'telextra',
      label: '1188 (indirizzo)',
      domain: 'www.1188.it',
      kind: AddressSearchEngineKind.telextra,
    ),
    AddressSearchEngine(
      id: 'bing',
      label: 'Bing',
      domain: 'www.bing.com',
      kind: AddressSearchEngineKind.bing,
    ),
    AddressSearchEngine(
      id: 'google',
      label: 'Google',
      domain: 'www.google.com',
      kind: AddressSearchEngineKind.google,
    ),
  ];

  static Future<List<AddressSearchEngine>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null || raw.isEmpty) return List.of(defaults);

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return List.of(defaults);
      return decoded
          .whereType<Map>()
          .map(
            (item) => AddressSearchEngine.fromJson(
              Map<String, dynamic>.from(item),
            ),
          )
          .where((engine) => engine.id.isNotEmpty && engine.domain.isNotEmpty)
          .toList();
    } catch (_) {
      return List.of(defaults);
    }
  }

  static Future<void> save(List<AddressSearchEngine> engines) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _prefsKey,
      jsonEncode(engines.map((engine) => engine.toJson()).toList()),
    );
  }

  /// Normalizza un dominio digitato dall'utente (`https://www.x.com/path` → `www.x.com`).
  static String? normalizeDomain(String raw) {
    var value = raw.trim().toLowerCase();
    if (value.isEmpty) return null;

    value = value.replaceFirst(RegExp(r'^https?://'), '');
    value = value.split('/').first.split('?').first.split('#').first.trim();
    if (value.isEmpty) return null;

    final host = value.startsWith('www.') ? value.substring(4) : value;
    final validHost = RegExp(
      r'^[a-z0-9]([a-z0-9\-]*[a-z0-9])?(\.[a-z0-9]([a-z0-9\-]*[a-z0-9])?)+$',
    ).hasMatch(host);
    if (!validHost) return null;

    return value;
  }

  static AddressSearchEngine engineFromDomain(String domain) {
    final host = domain.toLowerCase();
    final bare = host.replaceFirst(RegExp(r'^www\.'), '');

    for (final preset in defaults) {
      final presetBare =
          preset.domain.toLowerCase().replaceFirst(RegExp(r'^www\.'), '');
      if (bare == presetBare) {
        return AddressSearchEngine(
          id: preset.id,
          label: preset.label,
          domain: preset.domain,
          kind: preset.kind,
        );
      }
    }

    return AddressSearchEngine(
      id: 'custom_$bare',
      label: bare,
      domain: host.startsWith('www.') ? host : bare,
      kind: AddressSearchEngineKind.custom,
    );
  }
}
