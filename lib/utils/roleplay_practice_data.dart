/// Normalizza le righe `practiceData` delle simulazioni Role Play.
abstract final class RoleplayPracticeData {
  /// Corregge etichette duplicate/errate (es. due «Rate da pagare»).
  static List<Map<String, dynamic>> normalize(List<dynamic> raw) {
    final items = <Map<String, dynamic>>[];
    for (final item in raw) {
      if (item is! Map) continue;
      items.add({
        'label': '${item['label'] ?? ''}'.trim(),
        'value': '${item['value'] ?? ''}'.trim(),
      });
    }

    var rateDaPagareCount = 0;
    var hasRatePagate = false;
    var hasRateTotali = false;

    for (final item in items) {
      final label = _compact(item['label'] as String);
      if (label == 'ratedapagare') rateDaPagareCount++;
      if (label == 'ratepagate') hasRatePagate = true;
      if (label == 'ratetotali' || label == 'ratetotali.') hasRateTotali = true;
    }

    if (rateDaPagareCount < 2 || hasRateTotali) {
      return items;
    }

    var seenRateDaPagare = 0;
    for (final item in items) {
      final label = _compact(item['label'] as String);
      if (label != 'ratedapagare') {
        if (label == 'ratepagate') hasRatePagate = true;
        continue;
      }
      seenRateDaPagare++;
      // Seconda (o successiva) «Rate da pagare»: di solito sono le rate totali.
      if (seenRateDaPagare >= 2 && (hasRatePagate || seenRateDaPagare > 1)) {
        item['label'] = 'Rate totali';
      }
    }

    return items;
  }

  static String _compact(String label) =>
      label.toLowerCase().replaceAll(RegExp(r'[\s._-]'), '');
}
