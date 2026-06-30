import '../models/building_resident_entry.dart';

/// Elimina duplicati tra fonti diverse (stesso nominativo/telefono).
abstract final class BuildingResidentsDedup {
  static List<BuildingResidentEntry> merge(
    List<BuildingResidentEntry> entries,
  ) {
    final out = <BuildingResidentEntry>[];
    final keys = <String>{};

    for (final entry in entries) {
      final key = _dedupKey(entry);
      if (keys.contains(key)) continue;
      keys.add(key);
      out.add(entry);
    }
    return out;
  }

  static String _dedupKey(BuildingResidentEntry entry) {
    final phone = _normalizePhone(entry.phone);
    if (phone != null && phone.length >= 9) {
      return 'phone:$phone';
    }

    final name = _normalizeName(entry.displayName);
    final address = _normalizeAddress(entry.address);
    return 'name:$name|addr:$address';
  }

  static String? _normalizePhone(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 9) return null;
    return digits.length > 10 ? digits.substring(digits.length - 10) : digits;
  }

  static String _normalizeName(String raw) {
    return raw
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-zàèéìòóù0-9\s]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static String _normalizeAddress(String raw) {
    return raw
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-zàèéìòóù0-9\s]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}
