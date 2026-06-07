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
    return data?['enabled'] == true;
  }

  static String blockedSectionName(Map<String, dynamic>? data) {
    return data?['section']?.toString() ?? all;
  }

  static bool isSectionBlocked(Map<String, dynamic>? data, String sectionName) {
    if (!isEnabled(data)) return false;

    final blocked = blockedSectionName(data);
    if (blocked == all) return true;
    return blocked == sectionName;
  }
}
