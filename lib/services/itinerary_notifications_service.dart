import 'package:cloud_firestore/cloud_firestore.dart';

/// Preferenze push per promemoria itinerario e avvisi pre-visita.
abstract final class ItineraryNotificationsService {
  static const String fieldEnabled = 'itineraryNotificationsEnabled';
  static const String fieldUpdatedAt = 'itineraryNotificationsUpdatedAt';

  static final _firestore = FirebaseFirestore.instance;

  static Future<bool> loadEnabled(String uid) async {
    return false;
  }

  /// Solo il flag itinerario (sempre disattivato).
  static Future<bool> loadItineraryField(String uid) async {
    return false;
  }

  /// Azzera il flag su Firestore se era ancora attivo.
  static Future<void> ensureDisabled(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    if (doc.data()?[fieldEnabled] == true) {
      await setEnabled(uid: uid, enabled: false);
    }
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
