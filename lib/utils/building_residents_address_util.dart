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

  /// Via/civico e città separati per elenchi ItaliaOnline (Pagine Bianche, 1188, …).
  static ({String streetQuery, String? cityQuery}) splitForDirectorySearch(
    String address,
  ) {
    final trimmed = address.trim();
    if (trimmed.isEmpty) {
      return (streetQuery: '', cityQuery: null);
    }

    final city = extractCity(trimmed);
    if (city == null) {
      return (streetQuery: trimmed, cityQuery: null);
    }

    var street = trimmed;
    if (trimmed.contains(',')) {
      final rawParts = trimmed
          .split(',')
          .map((part) => part.trim())
          .where((part) => part.isNotEmpty)
          .toList();
      if (rawParts.length >= 2) {
        var lastPart = rawParts.last;
        lastPart = lastPart.replaceAll(RegExp(r'^\d+[a-zA-Z]?\s*'), '').trim();
        lastPart = lastPart
            .replaceAll(
              RegExp('\\b${RegExp.escape(city)}\\b', caseSensitive: false),
              '',
            )
            .trim();
        if (lastPart.isEmpty) {
          street = rawParts.sublist(0, rawParts.length - 1).join(', ');
        } else {
          final head = rawParts.sublist(0, rawParts.length - 1).join(', ');
          street = head.isEmpty ? lastPart : '$head, $lastPart';
        }
      }
    } else {
      street = trimmed
          .replaceAll(
            RegExp('\\b${RegExp.escape(city)}\\s*\$', caseSensitive: false),
            '',
          )
          .trim();
    }

    street = street.replaceAll(RegExp(r'\s+'), ' ').trim();
    street = street.replaceAll(RegExp(r'[,\s-]+$'), '').trim();
    if (street.isEmpty) street = trimmed;

    return (streetQuery: street, cityQuery: city);
  }

  /// Varianti di ricerca: completa, senza civico, solo via + città.
  static List<String> searchVariants(String address) {
    final trimmed = address.trim();
    if (trimmed.isEmpty) return const [];

    final variants = <String>{trimmed};

    final withoutCivic = stripCivicNumber(trimmed);
    if (withoutCivic.isNotEmpty) variants.add(withoutCivic);

    final parts = splitForDirectorySearch(trimmed);
    if (parts.cityQuery != null && parts.cityQuery!.isNotEmpty) {
      final streetOnly = stripCivicNumber(parts.streetQuery);
      if (streetOnly.isNotEmpty) {
        variants.add('$streetOnly, ${parts.cityQuery}');
        variants.add('$streetOnly ${parts.cityQuery}');
      }
      variants.add(parts.cityQuery!);
    }

    return variants.toList();
  }

  static String stripCivicNumber(String address) {
    var result = address.trim();
    result = result.replaceAll(
      RegExp(r'\b(n\.?|n°|civico)\s*\d+[a-zA-Z]?\b', caseSensitive: false),
      ' ',
    );
    result = result.replaceAll(
      RegExp(r',\s*\d+[a-zA-Z]?\b'),
      '',
    );
    result = result.replaceAll(
      RegExp(r'\b\d+[a-zA-Z]?\b(?=\s*,)'),
      '',
    );
    result = result.replaceAll(RegExp(r'\s+'), ' ').trim();
    result = result.replaceAll(RegExp(r',\s*,+'), ',');
    result = result.replaceAll(RegExp(r'^[,\s-]+|[,\s-]+$'), '').trim();
    return result;
  }

  /// Parametri query per /ricerca su portali ItaliaOnline.
  ///
  /// [tab] seleziona il filtro PB (es. `indirizzo`, `privati`, `aziende`).
  /// Via/civico in [qs], città in [dv]: così il sito apre già col tipo giusto.
  static Map<String, String> italiaOnlineQueryParams(
    String address, {
    String tab = 'indirizzo',
  }) {
    final trimmed = address.trim();
    final parts = splitForDirectorySearch(trimmed);
    final params = <String, String>{'tab': tab};

    final street = parts.streetQuery.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (street.isNotEmpty) {
      params['qs'] = street;
    } else if (trimmed.isNotEmpty) {
      params['qs'] = trimmed;
    }

    final city = parts.cityQuery?.trim();
    if (city != null && city.isNotEmpty) {
      params['dv'] = city;
    }

    return params;
  }

  /// Query testuale per motori web (Bing, Google).
  static String webSearchQuery(String address) {
    final parts = splitForDirectorySearch(address.trim());
    final street = parts.streetQuery.replaceAll(RegExp(r'\s+'), ' ').trim();
    final city = parts.cityQuery?.trim();

    if (city != null && city.isNotEmpty) {
      if (street.isNotEmpty) {
        return '"$street" $city telefono elenco privati indirizzo';
      }
      return '$city telefono elenco privati indirizzo';
    }

    return '"${address.trim()}" telefono elenco privati indirizzo';
  }

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
    final withoutCivic = stripCivicNumber(address);
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

  static bool matchesQuery(String query, String candidate) {
    return matchesListingAddress(query, candidate);
  }

  /// Filtro elenco: rigoroso (civico se presente) oppure flessibile.
  static bool matchesListingAddress(
    String query,
    String listingAddress, {
    String? extraText,
    bool strict = true,
  }) {
    if (_matchesListingAddressCore(
      query,
      listingAddress,
      strict: strict,
    )) {
      return true;
    }
    if (extraText != null && extraText.trim().isNotEmpty) {
      return _matchesListingAddressCore(
        query,
        extraText,
        strict: strict,
      );
    }
    return false;
  }

  static bool _matchesListingAddressCore(
    String query,
    String text, {
    required bool strict,
  }) {
    final candidate = text.trim();
    if (candidate.isEmpty) return false;

    final normalizedCandidate = normalize(candidate);
    if (normalizedCandidate.isEmpty) return false;

    final city = extractCity(query);
    final civic = extractCivicNumber(query);
    final streetNames = streetNameTokens(query);

    if (streetNames.isEmpty) {
      final normalizedQuery = normalize(stripCivicNumber(query));
      if (normalizedQuery.length >= 3 &&
          normalizedCandidate.contains(normalizedQuery)) {
        return true;
      }
      if (city != null &&
          city.length >= 3 &&
          normalizedCandidate.contains(city)) {
        return true;
      }
      return normalizedCandidate.contains(normalize(query));
    }

    final matchedTokens = streetNames
        .where((token) => normalizedCandidate.contains(token))
        .length;

    if (strict) {
      if (matchedTokens < streetNames.length) return false;

      if (civic != null && !_containsCivic(normalizedCandidate, civic)) {
        return false;
      }

      if (city != null && city.length >= 3) {
        return normalizedCandidate.contains(city);
      }

      return matchedTokens == streetNames.length;
    }

    // Flessibile: almeno un token di via + città se nota; civico facoltativo.
    if (matchedTokens == 0) return false;

    if (city != null && city.length >= 3) {
      return normalizedCandidate.contains(city);
    }

    return true;
  }

  /// Ultimo filtro per risultati restituiti dagli elenchi sulla stessa città.
  static bool matchesDirectoryAreaResult(
    String query,
    String listingAddress, {
    String? extraText,
  }) {
    final city = extractCity(query);
    final haystack = normalize(
      '$listingAddress ${extraText ?? ''}',
    );
    if (haystack.length < 5) return false;
    if (city != null && city.length >= 3) {
      return haystack.contains(city);
    }
    final streetNames = streetNameTokens(query);
    if (streetNames.isEmpty) return true;
    return streetNames.any((token) => haystack.contains(token));
  }

  static bool _containsCivic(String text, String civic) {
    return RegExp(
      r'(^|[^\d])' + RegExp.escape(civic) + r'([a-z]?(?=[^\d]|$)|$)',
      caseSensitive: false,
    ).hasMatch(text);
  }
}
