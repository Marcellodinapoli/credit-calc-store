import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/firestore_user_scope.dart';
import '../models/field_reminder.dart';

abstract final class FieldReminderService {
  static CollectionReference<Map<String, dynamic>> get _col =>
      FirebaseFirestore.instance.collection('field_reminders');

  static Stream<List<FieldReminder>> watchUpcoming() {
    final userId = FirestoreUserScope.uid;
    if (userId == null) return Stream.value(const []);

    return _col.where('userId', isEqualTo: userId).snapshots().map((snap) {
      final items = snap.docs.map(FieldReminder.fromDoc).toList();
      items.sort((a, b) => a.remindAt.compareTo(b.remindAt));
      return items;
    });
  }

  static Future<String> save({
    String? id,
    required String title,
    required DateTime remindAt,
    String? notes,
    String? visitId,
  }) async {
    final userId = FirestoreUserScope.uid;
    if (userId == null) throw StateError('Utente non autenticato');

    final reminder = FieldReminder(
      id: id ?? '',
      userId: userId,
      title: title.trim(),
      remindAt: remindAt,
      notes: notes?.trim(),
      visitId: visitId,
    );

    final data = FirestoreUserScope.withOwner({
      ...reminder.toFirestore(resetPushSent: true),
      if (id == null) 'createdAt': FieldValue.serverTimestamp(),
      if (id == null) 'pushSent': false,
    });

    if (id == null || id.isEmpty) {
      final ref = await _col.add(data);
      return ref.id;
    }

    await _col.doc(id).set(data, SetOptions(merge: true));
    return id;
  }

  static Future<void> delete(String id) => _col.doc(id).delete();
}
