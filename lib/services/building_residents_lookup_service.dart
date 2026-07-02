import '../config/building_residents_backend_config.dart';
import '../models/building_resident_entry.dart';
import '../utils/building_residents_address_util.dart';
import '../utils/directory_web_uri_util.dart';
import 'building_residents_dedup.dart';
import 'directory/bing_web_search_service.dart';
import 'directory/duckduckgo_web_search_service.dart';
import 'directory/pagine_gialle_directory_service.dart';
import 'directory/pagine_bianche_directory_service.dart';
import 'directory/telextra_directory_service.dart';

/// Ricerca nominativi a un civico tramite elenchi pubblici web (senza dati CreditCalc).
abstract final class BuildingResidentsLookupService {
  static const _allSourceLabels = [
    'Pagine Bianche — indirizzo',
    'Pagine Bianche — privati',
    'Pagine Bianche — aziende',
    'Pagine Gialle',
    'Telextra — 1188 / elenchi telefonici',
    'Telextra — ricerca web',
    'DuckDuckGo (elenchi web)',
    'Bing (elenchi web)',
  ];

  static Future<BuildingResidentsLookupResult> lookup(String address) async {
    final query = address.trim();
    if (query.length < 3) {
      throw ArgumentError(
        'Inserisci almeno via e città (il numero civico è facoltativo).',
      );
    }

    final searchQueries = BuildingResidentsAddressUtil.searchVariants(query);

    final results = await Future.wait([
      _searchPb(searchQueries, 'indirizzo'),
      _searchPb(searchQueries, 'privati'),
      _searchPb(searchQueries, 'aziende'),
      _searchPg(searchQueries),
      _searchTelextra(searchQueries),
      _searchDdg(searchQueries),
      _searchBing(searchQueries),
    ]);

    final pbIndirizzo = _filterRelevant(query, results[0]);
    final pbPrivati = _filterRelevant(query, results[1]);
    final pbAziende = _filterRelevant(query, results[2]);
    final pagineGialle = _filterRelevant(query, results[3]);
    final telextra = _filterRelevant(query, results[4]);
    final ddg = _filterRelevant(query, results[5]);
    final bing = _filterRelevant(query, results[6]);

    final searchedSources = <String>[];
    void markIfHit(String label, List<BuildingResidentEntry> entries) {
      if (entries.isNotEmpty) searchedSources.add(label);
    }

    markIfHit('Pagine Bianche — indirizzo', pbIndirizzo);
    markIfHit('Pagine Bianche — privati', pbPrivati);
    markIfHit('Pagine Bianche — aziende', pbAziende);
    markIfHit('Pagine Gialle', pagineGialle);
    markIfHit('Telextra', telextra);
    markIfHit('DuckDuckGo (elenchi web)', ddg);
    markIfHit('Bing (elenchi web)', bing);

    final merged = BuildingResidentsDedup.merge([
      ...pbIndirizzo,
      ...pbPrivati,
      ...pbAziende,
      ...pagineGialle,
      ...telextra,
      ...ddg,
      ...bing,
    ]);

    String? notes;
    if (merged.isEmpty) {
      notes =
          'Nessun nominativo trovato al civico indicato negli elenchi consultati. '
          'Gli elenchi online spesso non pubblicano i privati residenziali: '
          'prova ad aprire Pagine Gialle o Pagine Bianche dal link in basso, oppure verifica '
          'in sede (campanello, portiere).';
    } else if (pbIndirizzo.isEmpty && pbPrivati.isEmpty) {
      notes =
          'Trovate solo attività/uffici o risultati web generici. I privati '
          'residenziali spesso non sono pubblicati online: verifica in sede.';
    }

    final aiNotes = await _optionalAiSummary(
      queryAddress: query,
      residents: merged,
    );
    if (aiNotes != null && aiNotes.isNotEmpty) {
      notes = notes == null ? aiNotes : '$notes\n\n$aiNotes';
    }

    return BuildingResidentsLookupResult(
      queryAddress: query,
      residents: merged,
      searchedSources: searchedSources,
      consultedSources: _allSourceLabels,
      notes: notes,
    );
  }

  static Future<List<BuildingResidentEntry>> _searchPb(
    List<String> queries,
    String tab,
  ) async {
    for (final query in queries) {
      final hits =
          await PagineBiancheDirectoryService.searchByAddress(query, tab: tab);
      if (hits.isNotEmpty) return hits;
    }
    return [];
  }

  static Future<List<BuildingResidentEntry>> _searchPg(
    List<String> queries,
  ) async {
    for (final query in queries) {
      final hits = await PagineGialleDirectoryService.searchByAddress(query);
      if (hits.isNotEmpty) return hits;
    }
    return [];
  }

  static Future<List<BuildingResidentEntry>> _searchTelextra(
    List<String> queries,
  ) async {
    for (final query in queries) {
      final hits = await TelextraDirectoryService.searchAddress(query);
      if (hits.isNotEmpty) return hits;
    }
    return [];
  }

  static Future<List<BuildingResidentEntry>> _searchDdg(
    List<String> queries,
  ) async {
    final out = <BuildingResidentEntry>[];
    for (final query in queries) {
      out.addAll(await DuckDuckGoWebSearchService.searchAddress(query));
    }
    return out;
  }

  static Future<List<BuildingResidentEntry>> _searchBing(
    List<String> queries,
  ) async {
    for (final query in queries) {
      final hits = await BingWebSearchService.searchAddress(query);
      if (hits.isNotEmpty) return hits;
    }
    return [];
  }

  static List<BuildingResidentEntry> _filterRelevant(
    String query,
    List<BuildingResidentEntry> entries,
  ) {
    List<BuildingResidentEntry> filtered = entries
        .where(
          (entry) => BuildingResidentsAddressUtil.matchesListingAddress(
            query,
            entry.address,
            extraText: entry.category,
            strict: true,
          ),
        )
        .toList();

    if (filtered.isEmpty) {
      filtered = entries
          .where(
            (entry) => BuildingResidentsAddressUtil.matchesListingAddress(
              query,
              entry.address,
              extraText: entry.category,
              strict: false,
            ),
          )
          .toList();
    }

    if (filtered.isEmpty) {
      filtered = entries
          .where(
            (entry) => BuildingResidentsAddressUtil.matchesDirectoryAreaResult(
              query,
              entry.address,
              extraText: entry.category,
            ),
          )
          .toList();
    }

    filtered.sort((a, b) {
      final aHasPhone = a.phone != null && a.phone!.length >= 9;
      final bHasPhone = b.phone != null && b.phone!.length >= 9;
      if (aHasPhone != bHasPhone) return aHasPhone ? -1 : 1;
      return a.displayName.compareTo(b.displayName);
    });
    return filtered;
  }

  static Future<String?> _optionalAiSummary({
    required String queryAddress,
    required List<BuildingResidentEntry> residents,
  }) async {
    if (!BuildingResidentsBackendConfig.enabled) return null;
    try {
      return await BuildingResidentsBackendConfig.summarize(
        address: queryAddress,
        residents: residents,
      );
    } catch (_) {
      return null;
    }
  }

  static Uri telextraWebUri(String address) {
    return TelextraDirectoryService.webSearchUri(address);
  }

  static Uri pagineGialleWebUri(String address) {
    return PagineGialleDirectoryService.searchUri(address);
  }

  static Uri pagineBiancheWebUri(String address) {
    return DirectoryWebUriUtil.italiaOnlineRicerca(
      'www.paginebianche.it',
      address,
      tab: 'indirizzo',
    );
  }

  static Uri bingWebUri(String address) {
    return Uri.https(
      'www.bing.com',
      '/search',
      {
        'q': BuildingResidentsAddressUtil.webSearchQuery(address),
        'cc': 'it',
      },
    );
  }

  static Uri googleWebUri(String address) {
    return Uri.https(
      'www.google.com',
      '/search',
      {'q': BuildingResidentsAddressUtil.webSearchQuery(address)},
    );
  }
}
