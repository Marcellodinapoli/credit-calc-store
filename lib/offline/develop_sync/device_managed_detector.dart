import 'package:cloud_firestore/cloud_firestore.dart';

/// Rileva account con dati Sviluppa gestiti sui dispositivi (es. dopo uso web).
abstract final class DeviceManagedDetector {
  static final _firestore = FirebaseFirestore.instance;

  static Future<bool> isDeviceManaged(String userId) async {
    if (userId.isEmpty) return false;
    final snap = await _firestore
        .collection('users')
        .doc(userId)
        .collection('public_usage')
        .doc('totals')
        .get();
    return snap.data()?['deviceManaged'] == true;
  }
}
