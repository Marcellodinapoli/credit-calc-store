import 'package:cloud_firestore/cloud_firestore.dart';

/// Sezioni configurabili da BackOffice (`settings/maintenance`).
abstract final class MaintenanceService {
  static const all = 'Tutto';
  static const creditForm = 'CreditForm';
  static const creditJob = 'CreditJob';
  static const creditCalc = 'CreditCalc';
  static const area = 'Area riservata';

  static Stream<DocumentSnapshot<Map<String, dynamic>>> watch() {
    return FirebaseFirestore.instance
        .collection('settings')
        .doc('maintenance')
        .snapshots();
  }

  static Map<String, dynamic>? dataFrom(
    DocumentSnapshot<Map<String, dynamic>>? snapshot,
  ) {
    return snapshot?.data();
  }

  static bool isEnabled(Map<String, dynamic>? data) {
    if (data == null) return false;
    final enabled = data['enabled'];
    if (enabled is bool) return enabled;
    if (enabled is num) return enabled != 0;
    if (enabled is String) {
      final normalized = enabled.trim().toLowerCase();
      return normalized == 'true' || normalized == '1';
    }
    return false;
  }

  static String blockedSectionName(Map<String, dynamic>? data) {
    final raw = data?['section']?.toString().trim();
    if (raw == null || raw.isEmpty) return all;
    return raw;
  }

  static bool isSectionBlocked(Map<String, dynamic>? data, String sectionName) {
    if (!isEnabled(data)) return false;

    final blocked = blockedSectionName(data);
    if (blocked == all) return true;
    return blocked == sectionName;
  }
}
