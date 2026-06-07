/// Regole di visibilità annunci in base al tipo utente Firestore.
abstract final class AnnouncementsTargeting {
  static String normalizeUserType(Object? type) {
    final value = type?.toString().trim();
    if (value == null || value.isEmpty) return 'public';
    return value;
  }

  static bool isVisibleForUser({
    required Map<String, dynamic> data,
    required String userType,
  }) {
    final target = data['target'] ?? 'all';
    final normalized = normalizeUserType(userType);
    return target == 'all' || target == normalized;
  }
}
