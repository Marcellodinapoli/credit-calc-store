/// Confronto versioni semantiche (es. 1.0.0, 1.2.10).
abstract final class AppVersionUtils {
  static List<int> parse(String version) {
    var cleaned = version.trim();
    final plus = cleaned.indexOf('+');
    if (plus >= 0) cleaned = cleaned.substring(0, plus);
    final dash = cleaned.indexOf('-');
    if (dash >= 0) cleaned = cleaned.substring(0, dash);
    if (cleaned.isEmpty) return [0];

    return cleaned.split('.').map((part) {
      final digits = part.replaceAll(RegExp(r'[^0-9]'), '');
      return int.tryParse(digits.isEmpty ? '0' : digits) ?? 0;
    }).toList();
  }

  /// `true` se [remote] è strettamente più recente di [local].
  static bool isNewer(String remote, String local) {
    final r = parse(remote);
    final l = parse(local);
    final length = r.length > l.length ? r.length : l.length;

    for (var i = 0; i < length; i++) {
      final rv = i < r.length ? r[i] : 0;
      final lv = i < l.length ? l[i] : 0;
      if (rv > lv) return true;
      if (rv < lv) return false;
    }
    return false;
  }
}
