import 'package:cloud_firestore/cloud_firestore.dart';

/// Preferenze push per promemoria itinerario e avvisi pre-visita.
abstract final class ItineraryNotificationsService {
  static const String fieldEnabled = 'itineraryNotificationsEnabled';
  static const String fieldUpdatedAt = 'itineraryNotificationsUpdatedAt';

  static final _firestore = FirebaseFirestore.instance;

  static Future<bool> loadEnabled(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    final data = doc.data() ?? {};
    return data['productNotificationsEnabled'] == true &&
        data[fieldEnabled] == true;
  }

  /// Solo il flag itinerario (senza richiedere le notifiche prodotto attive).
  static Future<bool> loadItineraryField(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    return doc.data()?[fieldEnabled] == true;
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
