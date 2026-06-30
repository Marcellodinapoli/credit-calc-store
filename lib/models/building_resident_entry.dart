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
    return switch (source) {
      'paginebianche_privati' => 'Pagine Bianche (privati)',
      'paginebianche_indirizzo' => 'Pagine Bianche (indirizzo)',
      'paginebianche_aziende' => 'Pagine Bianche (aziende)',
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
