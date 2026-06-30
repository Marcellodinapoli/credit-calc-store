/// Normalizzazione e confronto indirizzi per ricerca inquilini.
abstract final class BuildingResidentsAddressUtil {
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

    final plain = RegExp(r'\b(\d+[a-zA-Z]?)\b').allMatches(address).toList();
    if (plain.isEmpty) return null;
    return plain.last.group(1)?.toLowerCase();
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

  static bool matchesQuery(String query, String candidate) {
    final q = normalize(query);
    final c = normalize(candidate);
    if (q.isEmpty || c.isEmpty) return false;

    final civic = extractCivicNumber(q);
    if (civic != null && !c.contains(civic)) return false;

    final tokens = streetTokens(q);
    if (tokens.isEmpty) return c.contains(q);
    var hits = 0;
    for (final token in tokens) {
      if (c.contains(token)) hits++;
    }
    return hits >= (tokens.length >= 2 ? 2 : 1);
  }
}
