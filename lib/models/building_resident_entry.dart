/// Persona o unità trovata in un elenco pubblico web.
class BuildingResidentEntry {
  const BuildingResidentEntry({
    required this.displayName,
    required this.address,
    required this.source,
    this.phone,
    this.category,
  });

  final String displayName;
  final String address;
  final String source;
  final String? phone;
  final String? category;

  String get sourceLabel {
    if (source.startsWith('telextra_')) {
      return switch (source) {
        'telextra_backend' => 'Telextra',
        'telextra_ddg' => 'Telextra (web)',
        _ when source.contains('1188') => 'Telextra / 1188',
        _ when source.contains('elenchi') => 'Telextra / Elenchi telefonici',
        _ => 'Telextra',
      };
    }
    return switch (source) {
      'paginebianche_privati' => 'Pagine Bianche (privati)',
      'paginebianche_indirizzo' => 'Pagine Bianche (indirizzo)',
      'paginebianche_aziende' => 'Pagine Bianche (aziende)',
      'paginegialle' => 'Pagine Gialle',
      'duckduckgo' => 'DuckDuckGo',
      'bing' => 'Bing',
      _ => source,
    };
  }
}

class BuildingResidentsLookupResult {
  const BuildingResidentsLookupResult({
    required this.queryAddress,
    required this.residents,
    required this.searchedSources,
    required this.consultedSources,
    this.notes,
  });

  final String queryAddress;
  final List<BuildingResidentEntry> residents;
  final List<String> searchedSources;
  final List<String> consultedSources;
  final String? notes;
}
