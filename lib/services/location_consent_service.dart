import 'package:cloud_firestore/cloud_firestore.dart';

/// Consenso in-app all'uso della posizione (itinerario e percorsi sul territorio).
abstract final class LocationConsentService {
  static const String fieldEnabled = 'locationConsentEnabled';
  static const String fieldUpdatedAt = 'locationConsentUpdatedAt';

  static final _firestore = FirebaseFirestore.instance;

  static Future<bool> loadEnabled(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    final data = doc.data() ?? {};
    return data['productNotificationsEnabled'] == true &&
        data['itineraryNotificationsEnabled'] == true &&
        data[fieldEnabled] == true;
  }

  static Future<void> setEnabled({
    required String uid,
    required bool enabled,
  }) async {
    await _firestore.collection('users').doc(uid).set(
      {
        fieldEnabled: enabled,
        fieldUpdatedAt: FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }
}
