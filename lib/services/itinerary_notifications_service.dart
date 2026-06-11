import 'package:cloud_firestore/cloud_firestore.dart';

/// Preferenze push per promemoria itinerario e avvisi pre-visita.
abstract final class ItineraryNotificationsService {
  static const String fieldEnabled = 'itineraryNotificationsEnabled';
  static const String fieldUpdatedAt = 'itineraryNotificationsUpdatedAt';

  static final _firestore = FirebaseFirestore.instance;

  static Future<bool> loadEnabled(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    final data = doc.data();
    if (data == null) return false;

    final explicit = data[fieldEnabled];
    if (explicit == false) return false;
    if (explicit == true) {
      return data['productNotificationsEnabled'] == true;
    }
    return data['productNotificationsEnabled'] == true;
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
