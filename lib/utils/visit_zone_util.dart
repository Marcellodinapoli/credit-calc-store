/// Estrae una zona leggibile dall'indirizzo (CAP+città o ultimo segmento).
String? extractZoneFromAddress(String address) {
  final trimmed = address.trim();
  if (trimmed.isEmpty) return null;

  final capMatch = RegExp(
    r"\b(\d{5})\s+([A-Za-zÀ-ÿ][A-Za-zÀ-ÿ\s'-]*)",
  ).firstMatch(trimmed);
  if (capMatch != null) {
    final cap = capMatch.group(1);
    final city = capMatch.group(2)?.trim();
    if (cap != null && city != null && city.isNotEmpty) {
      return '$cap $city';
    }
  }

  final parts = trimmed.split(',');
  if (parts.length > 1) {
    final last = parts.last.trim();
    if (last.isNotEmpty) return last;
  }

  return trimmed.length > 48 ? '${trimmed.substring(0, 45)}...' : trimmed;
}
