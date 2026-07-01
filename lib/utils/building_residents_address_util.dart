/// Normalizzazione e confronto indirizzi per ricerca inquilini.
abstract final class BuildingResidentsAddressUtil {
  static const _streetTypeWords = {
    'via',
    'viale',
    'vle',
    'corso',
    'cso',
    'piazza',
    'pzza',
    'largo',
    'vicolo',
    'vico',
    'strada',
    'str',
    'localita',
    'loc',
    'frazione',
    'fr',
    'piazzale',
    'lungomare',
    'contrada',
    'traversa',
  };

  static String normalize(String raw) {
    return raw
        .toLowerCase()
        .replaceAll('.', '')
        .replaceAll('\'', '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static String? extractCivicNumber(String address) {
    final match = RegExp(
      r'\b(n\.?|n°|civico|n)\s*(\d+[a-zA-Z]?)\b',
      caseSensitive: false,
    ).firstMatch(address);
    if (match != null) return match.group(2)?.toLowerCase();

    final commaParts = address.split(',');
    if (commaParts.length >= 2) {
      final beforeCity = commaParts[commaParts.length - 2];
      final civicInPart = RegExp(r'\b(\d+[a-zA-Z]?)\b')
          .allMatches(beforeCity)
          .toList();
      if (civicInPart.isNotEmpty) {
        return civicInPart.last.group(1)?.toLowerCase();
      }
    }

    final plain = RegExp(r'\b(\d+[a-zA-Z]?)\b').allMatches(address).toList();
    if (plain.isEmpty) return null;
    return plain.last.group(1)?.toLowerCase();
  }

  static String? extractCity(String address) {
    final parts = address
        .split(',')
        .map((part) => normalize(part.trim()))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.length >= 2) {
      var cityPart = parts.last;
      cityPart = cityPart.replaceAll(RegExp(r'^\d+[a-z]?\s*'), '').trim();
      if (cityPart.length >= 3) return cityPart;
    }

    final tokens = normalize(address)
        .split(RegExp(r'[,\s/]+'))
        .where((word) => word.length > 2 && !RegExp(r'^\d').hasMatch(word))
        .toList();
    if (tokens.length < 2) return null;
    final last = tokens.last;
    if (_streetTypeWords.contains(last)) return null;
    return last;
  }

  static List<String> streetTokens(String address) {
    final withoutCivic = address.replaceAll(
      RegExp(r'\b(n\.?|n°|civico)\s*\d+[a-zA-Z]?\b', caseSensitive: false),
      ' ',
    );
    return normalize(withoutCivic)
        .split(RegExp(r'[,\s/]+'))
        .where((w) => w.length > 2 && !RegExp(r'^\d').hasMatch(w))
        .take(4)
        .toList();
  }

  static List<String> streetNameTokens(String address) {
    final city = extractCity(address);
    return streetTokens(address)
        .where((token) => !_streetTypeWords.contains(token))
        .where((token) => city == null || token != city)
        .toList();
  }

  /// Filtro rigoroso: l'indirizzo dell'elenco deve coincidere con via, civico e città.
  static bool matchesListingAddress(String query, String listingAddress) {
    final candidate = listingAddress.trim();
    if (candidate.isEmpty) return false;

    final normalizedCandidate = normalize(candidate);
    if (normalizedCandidate.isEmpty) return false;

    final city = extractCity(query);
    final civic = extractCivicNumber(query);
    if (civic != null && !_containsCivic(normalizedCandidate, civic)) {
      return false;
    }

    final streetNames = streetNameTokens(query);
    if (streetNames.isEmpty) {
      return normalizedCandidate.contains(normalize(query));
    }

    final streetOk =
        streetNames.every((token) => normalizedCandidate.contains(token));
    if (!streetOk) return false;

    if (city != null && city.length >= 3 && normalizedCandidate.contains(city)) {
      return true;
    }

    // Pagine Bianche spesso omette la città nella riga indirizzo: basta via + civico.
    return civic != null;
  }

  static bool matchesQuery(String query, String candidate) {
    return matchesListingAddress(query, candidate);
  }

  static bool _containsCivic(String text, String civic) {
    return RegExp(
      r'(^|[^\d])' + RegExp.escape(civic) + r'([a-z]?(?=[^\d]|$)|$)',
      caseSensitive: false,
    ).hasMatch(text);
  }
}
