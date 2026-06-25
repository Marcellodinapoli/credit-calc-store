import '../core/firestore_user_scope.dart';
import '../models/field_activity.dart';
import 'itinerary_storage.dart';

abstract final class FieldActivityService {
  static ItineraryStorage get _storage => ItineraryStorage.instance;

  static Stream<List<FieldActivity>> watchAll() => _storage.watchAllActivities();

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

    final isNew = id == null || id.isEmpty;
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

    return _storage.saveActivity(
      id: id,
      activity: activity,
      isNew: isNew,
    );
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

  static Future<void> delete(String id) => _storage.deleteActivity(id);
}
