class AddressScanResult {
  const AddressScanResult({
    this.companyName,
    required this.address,
  });

  final String? companyName;
  final String address;
}

abstract final class AddressTextParser {
  static final _capRe = RegExp(r'\b\d{5}\b');
  static final _streetRe = RegExp(
    r'\b(via|viale|v\.|v\.le|piazza|p\.za|p\.zza|corso|c\.so|strada|str\.|'
    r'località|loc\.|contrada|c\.da|frazione|piazzale|largo|vicolo)\b',
    caseSensitive: false,
  );
  static final _noiseRe = RegExp(
    r'@|www\.|https?://|tel\.?|telefono|fax|p\.?\s*iva|partita\s*iva|'
    r'cod\.?\s*fisc|cell\.?|mobile',
    caseSensitive: false,
  );

  static String extractLikelyAddress(String raw) => parseScannedText(raw).address;

  static AddressScanResult parseScannedText(String raw) {
    final lines = _normalizedLines(raw);
    if (lines.isEmpty) {
      return AddressScanResult(address: raw.trim());
    }
    if (lines.length == 1) {
      return _parseSingleLine(lines.first);
    }

    final scores = [for (final line in lines) _addressScore(line)];

    var anchor = 0;
    var anchorScore = scores.first;
    for (var i = 1; i < lines.length; i++) {
      if (scores[i] > anchorScore) {
        anchor = i;
        anchorScore = scores[i];
      }
    }

    if (anchorScore < 1) {
      final companyName =
          _isLikelyNameLine(lines.first, scores.first) ? lines.first : null;
      final addressLines =
          companyName == null ? lines : lines.skip(1).toList();
      return AddressScanResult(
        companyName: companyName,
        address: addressLines.join(', '),
      );
    }

    var start = anchor;
    var end = anchor;

    if (start > 0 &&
        _streetRe.hasMatch(lines[start - 1]) &&
        !_streetRe.hasMatch(lines[start])) {
      start--;
    }

    while (end < lines.length - 1 &&
        _belongsToAddressBlock(lines[end + 1], scores[end + 1])) {
      end++;
    }

    final address = lines.sublist(start, end + 1).join(', ');
    final nameParts = <String>[];
    for (var i = 0; i < start; i++) {
      if (_isLikelyNameLine(lines[i], scores[i])) {
        nameParts.add(lines[i]);
      }
    }

    String? companyName =
        nameParts.isEmpty ? null : nameParts.join(' ').trim();
    if ((companyName == null || companyName.isEmpty) && start > 0) {
      final candidate = lines[start - 1].trim();
      if (_isLikelyNameLine(candidate, scores[start - 1])) {
        companyName = candidate;
      }
    }

    return AddressScanResult(
      companyName: companyName?.isEmpty == true ? null : companyName,
      address: address.isEmpty ? lines.join(', ') : address,
    );
  }

  static AddressScanResult _parseSingleLine(String line) {
    final streetMatch = _streetRe.firstMatch(line);
    if (streetMatch != null && streetMatch.start > 2) {
      final name = line.substring(0, streetMatch.start).trim();
      final address = line.substring(streetMatch.start).trim();
      if (_isLikelyNameLine(name, _addressScore(name)) && address.isNotEmpty) {
        return AddressScanResult(companyName: name, address: address);
      }
    }
    return AddressScanResult(address: line);
  }

  static List<String> _normalizedLines(String raw) {
    return raw
        .split(RegExp(r'[\r\n]+'))
        .map((line) => line.trim())
        .where((line) => line.length > 2)
        .toList();
  }

  static int _addressScore(String line) {
    var value = 0;
    if (_capRe.hasMatch(line)) value += 3;
    if (_streetRe.hasMatch(line)) value += 4;
    if (RegExp(r'\d').hasMatch(line)) value += 1;
    if (RegExp(r'\b[A-Z]{2}\b$').hasMatch(line.trim())) value += 2;
    if (line.length > 90) value -= 2;
    if (_noiseRe.hasMatch(line)) value -= 5;
    return value;
  }

  static bool _belongsToAddressBlock(String line, int lineScore) {
    if (lineScore >= 1) return true;
    if (_capRe.hasMatch(line)) return true;
    if (_streetRe.hasMatch(line)) return true;
    if (RegExp(r'^\d{5}\s+[A-Za-zÀ-ÿ]').hasMatch(line)) return true;
    if (RegExp(r'\b\d{5}\b').hasMatch(line) && line.length < 64) return true;
    return false;
  }

  static bool _isLikelyNameLine(String line, int lineScore) {
    if (lineScore >= 3) return false;
    if (_capRe.hasMatch(line)) return false;
    if (_streetRe.hasMatch(line) && RegExp(r'\d').hasMatch(line)) return false;
    if (_noiseRe.hasMatch(line)) return false;
    if (line.length < 2 || line.length > 90) return false;
    if (RegExp(r'^\+?\d[\d\s./-]{6,}$').hasMatch(line)) return false;
    return true;
  }
}
