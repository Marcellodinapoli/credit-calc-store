import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/firestore_user_scope.dart';
import '../models/field_activity.dart';

abstract final class FieldActivityService {
  static CollectionReference<Map<String, dynamic>> get _col =>
      FirebaseFirestore.instance.collection('field_activities');

  static Stream<List<FieldActivity>> watchAll() {
    final userId = FirestoreUserScope.uid;
    if (userId == null) return Stream.value(const []);

    return _col.where('userId', isEqualTo: userId).snapshots().map((snap) {
      final items = snap.docs.map(FieldActivity.fromDoc).toList();
      items.sort((a, b) {
        if (a.completed != b.completed) {
          return a.completed ? 1 : -1;
        }
        final dueA = a.dueAt ?? DateTime(2100);
        final dueB = b.dueAt ?? DateTime(2100);
        return dueA.compareTo(dueB);
      });
      return items;
    });
  }

  static Future<String> save({
    String? id,
    required String title,
    bool completed = false,
    String? notes,
    DateTime? dueAt,
    String? visitId,
    int? recurrenceDays,
  }) async {
    final userId = FirestoreUserScope.uid;
    if (userId == null) throw StateError('Utente non autenticato');

    final activity = FieldActivity(
      id: id ?? '',
      userId: userId,
      title: title.trim(),
      completed: completed,
      notes: notes?.trim(),
      dueAt: dueAt,
      visitId: visitId,
      recurrenceDays: recurrenceDays,
    );

    final data = FirestoreUserScope.withOwner({
      ...activity.toFirestore(),
      if (id == null) 'createdAt': FieldValue.serverTimestamp(),
    });

    if (id == null || id.isEmpty) {
      final ref = await _col.add(data);
      return ref.id;
    }

    await _col.doc(id).set(data, SetOptions(merge: true));
    return id;
  }

  static Future<void> toggleCompleted(FieldActivity activity) async {
    final nextCompleted = !activity.completed;
    await save(
      id: activity.id,
      title: activity.title,
      completed: nextCompleted,
      notes: activity.notes,
      dueAt: activity.dueAt,
      visitId: activity.visitId,
      recurrenceDays: activity.recurrenceDays,
    );
    if (nextCompleted) {
      await _spawnRecurrenceIfNeeded(activity);
    }
  }

  static Future<void> scheduleFollowUp(
    FieldActivity activity, {
    required int days,
  }) {
    final due = DateTime.now().add(Duration(days: days));
    return save(
      title: activity.title.startsWith('Richiama: ')
          ? activity.title
          : 'Richiama: ${activity.title}',
      notes: activity.notes,
      dueAt: due,
      visitId: activity.visitId,
      recurrenceDays: days,
    );
  }

  static Future<void> _spawnRecurrenceIfNeeded(FieldActivity activity) async {
    final days = activity.recurrenceDays;
    if (days == null || days <= 0) return;

    await save(
      title: activity.title,
      notes: activity.notes,
      dueAt: DateTime.now().add(Duration(days: days)),
      visitId: activity.visitId,
      recurrenceDays: days,
    );
  }

  static Future<void> delete(String id) => _col.doc(id).delete();
}
