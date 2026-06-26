import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:credit_calc_core/credit_calc_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'bk_admin_service.dart';

abstract final class PlanLimitsAdminService {
  static Future<void> savePlans(Map<String, Map<String, dynamic>> plans) async {
    if (!await BkAdminService.isAdmin(forceRefresh: true)) {
      throw StateError('Accesso negato');
    }

    final uid = FirebaseAuth.instance.currentUser?.uid;
    await FirebaseFirestore.instance
        .collection('settings')
        .doc(PublicPlanLimitsConfigService.docId)
        .set({
      'plans': plans,
      'updatedAt': FieldValue.serverTimestamp(),
      if (uid != null) 'updatedBy': uid,
    }, SetOptions(merge: true));
  }
}
