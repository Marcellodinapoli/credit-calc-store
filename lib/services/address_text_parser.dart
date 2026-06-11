abstract final class AddressTextParser {
  static String extractLikelyAddress(String raw) {
    final lines = raw
        .split(RegExp(r'[\r\n]+'))
        .map((line) => line.trim())
        .where((line) => line.length > 2)
        .toList();

    if (lines.isEmpty) return raw.trim();

    final capRe = RegExp(r'\b\d{5}\b');
    final streetRe = RegExp(
      r'\b(via|viale|v\.|v\.le|piazza|p\.za|p\.zza|corso|c\.so|strada|str\.|'
      r'località|loc\.|contrada|c\.da|frazione|piazzale|largo|vicolo)\b',
      caseSensitive: false,
    );

    int score(String line) {
      var value = 0;
      if (capRe.hasMatch(line)) value += 3;
      if (streetRe.hasMatch(line)) value += 4;
      if (RegExp(r'\d').hasMatch(line)) value += 1;
      if (line.length > 90) value -= 2;
      if (RegExp(r'@|www\.|http', caseSensitive: false).hasMatch(line)) {
        value -= 5;
      }
      return value;
    }

    var bestIndex = 0;
    var bestScore = -999;
    for (var i = 0; i < lines.length; i++) {
      final lineScore = score(lines[i]);
      if (lineScore > bestScore) {
        bestScore = lineScore;
        bestIndex = i;
      }
    }

    if (bestScore < 1) {
      return lines.take(3).join(', ');
    }

    final parts = <String>[lines[bestIndex]];
    if (bestIndex + 1 < lines.length) {
      final next = lines[bestIndex + 1];
      if (capRe.hasMatch(next) || next.length < 48) {
        parts.add(next);
      }
    }
    if (bestIndex > 0) {
      final prev = lines[bestIndex - 1];
      if (streetRe.hasMatch(prev) && !streetRe.hasMatch(parts.first)) {
        parts.insert(0, prev);
      }
    }

    return parts.join(', ');
  }
}
