abstract final class DirectoryHtmlUtils {
  static const userAgent = 'Mozilla/5.0 CreditCalc/1.0 (+https://creditcore.it)';

  static String? firstMatch(String block, List<RegExp> patterns) {
    for (final pattern in patterns) {
      final match = pattern.firstMatch(block);
      if (match != null && match.groupCount >= 1) {
        final value = match.group(1)?.trim();
        if (value != null && value.isNotEmpty) return value;
      }
    }
    return null;
  }

  static String decodeHtmlEntities(String raw) {
    return raw
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&#x27;', "'")
        .replaceAll('&#39;', "'")
        .replaceAll('&agrave;', 'à')
        .replaceAll('&egrave;', 'è')
        .replaceAll('&igrave;', 'ì')
        .replaceAll('&ograve;', 'ò')
        .replaceAll('&ugrave;', 'ù')
        .replaceAll(RegExp(r'<[^>]+>'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static String? extractPhone(String text) {
    final mobile = RegExp(r'\b3\d{8,9}\b').firstMatch(text);
    if (mobile != null) return mobile.group(0);

    final landline = RegExp(r'\b0\d{5,11}\b').firstMatch(text);
    return landline?.group(0);
  }

  static bool isDirectoryHost(String urlOrText) {
    final lower = urlOrText.toLowerCase();
    const hosts = [
      'paginebianche',
      'paginegialle',
      '1188.it',
      'elenchitelefonici',
      'telextra',
      'virgilio.it',
      'libero.it',
      'paginemail',
      'trovanumeri',
      'tuttitalia',
    ];
    return hosts.any(lower.contains);
  }
}
