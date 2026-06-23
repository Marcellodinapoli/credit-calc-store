import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/warmup_contestation.dart';
import '../../services/warmup_contestation_service.dart';
import 'bk_admin_service.dart';

/// Moderazione contestazioni warm-up (backoffice).
abstract final class WarmupContestationAdminService {
  static final _firestore = FirebaseFirestore.instance;

  static Future<void> _requireAdmin() async {
    if (!await BkAdminService.isAdmin(forceRefresh: true)) {
      throw StateError('Accesso riservato agli amministratori.');
    }
  }

  static Future<void> approve(String id) async {
    await _requireAdmin();
    await _firestore
        .collection(WarmupContestationService.collection)
        .doc(id)
        .update({
      'status': WarmupContestationStatus.approved.firestoreValue,
      'rejectionNote': FieldValue.delete(),
      'reviewedAt': FieldValue.serverTimestamp(),
      'reviewedBy': 'admin',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> reject({
    required String id,
    String? note,
  }) async {
    await _requireAdmin();
    await _firestore
        .collection(WarmupContestationService.collection)
        .doc(id)
        .update({
      'status': WarmupContestationStatus.rejected.firestoreValue,
      'rejectionNote': (note ?? '').trim().isEmpty ? null : note!.trim(),
      'reviewedAt': FieldValue.serverTimestamp(),
      'reviewedBy': 'admin',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
