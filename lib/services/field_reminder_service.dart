import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/firestore_user_scope.dart';
import '../models/field_reminder.dart';
import 'field_reminder_notification_service.dart';

class FieldReminderSaveResult {
  const FieldReminderSaveResult({
    required this.id,
    required this.schedule,
  });

  final String id;
  final FieldReminderScheduleResult schedule;
}

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

  static Future<FieldReminderSaveResult> save({
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

    final String savedId;
    if (id == null || id.isEmpty) {
      final ref = await _col.add(data);
      savedId = ref.id;
    } else {
      await _col.doc(id).set(data, SetOptions(merge: true));
      savedId = id;
    }

    await cancelLocalNotification(savedId);
    final schedule = await _scheduleLocalNotification(
      FieldReminder(
        id: savedId,
        userId: userId,
        title: reminder.title,
        remindAt: remindAt,
        notes: reminder.notes,
        visitId: visitId,
      ),
    );
    return FieldReminderSaveResult(id: savedId, schedule: schedule);
  }

  static Future<void> delete(String id) async {
    await cancelLocalNotification(id);
    await _col.doc(id).delete();
  }

  static Future<List<FieldReminder>> fetchAllForUser(String userId) async {
    final snap = await _col.where('userId', isEqualTo: userId).get();
    final items = snap.docs.map(FieldReminder.fromDoc).toList();
    items.sort((a, b) => a.remindAt.compareTo(b.remindAt));
    return items;
  }

  static Future<void> cancelLocalNotification(String id) =>
      FieldReminderNotificationService.cancelForReminder(id);

  static Future<FieldReminderScheduleResult> _scheduleLocalNotification(
    FieldReminder reminder,
  ) =>
      FieldReminderNotificationService.scheduleIfEnabled(reminder);
}
