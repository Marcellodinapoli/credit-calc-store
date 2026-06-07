/// Helper codici Work (solo lettura, senza dipendenze web).
abstract final class WorkCodeHelpers {
  static bool looksLikeWorkCode(String code) {
    return RegExp(r'^CP-[A-Z0-9]+-(COL|SUP)$').hasMatch(code);
  }

  static String normalizeRoleValue(dynamic value) {
    final raw = (value ?? '').toString().trim().toLowerCase();
    if (raw == 'sup' || raw == 'supervisor') return 'supervisor';
    if (raw == 'col' || raw == 'collaborator') return 'collaborator';
    return raw;
  }
}
