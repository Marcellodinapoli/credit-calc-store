import '../config/building_residents_backend_config.dart';
import '../models/building_resident_entry.dart';
import 'building_residents_dedup.dart';
import 'directory/bing_web_search_service.dart';
import 'directory/duckduckgo_web_search_service.dart';
import 'directory/pagine_bianche_directory_service.dart';

/// Ricerca nominativi a un civico tramite elenchi pubblici web (senza dati CreditCalc).
abstract final class BuildingResidentsLookupService {
  static const _allSourceLabels = [
    'Pagine Bianche — indirizzo',
    'Pagine Bianche — privati',
    'Pagine Bianche — aziende',
    'DuckDuckGo (elenchi web)',
    'Bing (elenchi web)',
  ];

  static Future<BuildingResidentsLookupResult> lookup(String address) async {
    final query = address.trim();
    if (query.length < 5) {
      throw ArgumentError('Inserisci un indirizzo più completo (via, civico e città).');
    }

    final results = await Future.wait([
      PagineBiancheDirectoryService.searchByAddress(query, tab: 'indirizzo'),
      PagineBiancheDirectoryService.searchByAddress(query, tab: 'privati'),
      PagineBiancheDirectoryService.searchByAddress(query, tab: 'aziende'),
      DuckDuckGoWebSearchService.searchAddress(query),
      BingWebSearchService.searchAddress(query),
    ]);

    final pbIndirizzo = results[0];
    final pbPrivati = results[1];
    final pbAziende = results[2];
    final ddg = results[3];
    final bing = results[4];

    final searchedSources = <String>[];
    void markIfHit(String label, List<BuildingResidentEntry> entries) {
      if (entries.isNotEmpty) searchedSources.add(label);
    }

    markIfHit('Pagine Bianche — indirizzo', pbIndirizzo);
    markIfHit('Pagine Bianche — privati', pbPrivati);
    markIfHit('Pagine Bianche — aziende', pbAziende);
    markIfHit('DuckDuckGo (elenchi web)', ddg);
    markIfHit('Bing (elenchi web)', bing);

    final merged = BuildingResidentsDedup.merge([
      ...pbIndirizzo,
      ...pbPrivati,
      ...pbAziende,
      ...ddg,
      ...bing,
    ]);

    String? notes;
    if (merged.isEmpty) {
      notes =
          'Nessun nominativo trovato negli elenchi consultati. '
          'Prova con via, numero civico e città completi, oppure apri '
          'una ricerca web dal link in basso. Per un elenco certo servono '
          'anagrafe comunale o indagini sul posto (campanello, portiere).';
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

  static Uri pagineBiancheWebUri(String address) {
    return Uri.https(
      'www.paginebianche.it',
      '/ricerca',
      {'qs': address.trim(), 'tab': 'indirizzo'},
    );
  }

  static Uri bingWebUri(String address) {
    return Uri.https(
      'www.bing.com',
      '/search',
      {
        'q': '"${address.trim()}" telefono elenco',
        'cc': 'it',
      },
    );
  }

  static Uri googleWebUri(String address) {
    return Uri.https(
      'www.google.com',
      '/search',
      {'q': '"${address.trim()}" telefono elenco'},
    );
  }
}
