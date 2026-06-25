import '../core/firestore_user_scope.dart';
import '../models/field_reminder.dart';
import 'field_reminder_notification_service.dart';
import 'itinerary_storage.dart';

class FieldReminderSaveResult {
  const FieldReminderSaveResult({
    required this.id,
    required this.schedule,
  });

  final String id;
  final FieldReminderScheduleResult schedule;
}

abstract final class FieldReminderService {
  static ItineraryStorage get _storage => ItineraryStorage.instance;

  static Stream<List<FieldReminder>> watchUpcoming() =>
      _storage.watchAllReminders();

  static Future<List<FieldReminder>> fetchAllForUser() =>
      _storage.fetchAllReminders();

  static Future<List<FieldReminder>> fetchAllForUserId(String userId) async {
    final current = FirestoreUserScope.uid;
    if (current == userId) return fetchAllForUser();
    return const [];
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

    final isNew = id == null || id.isEmpty;
    final reminder = FieldReminder(
      id: id ?? '',
      userId: userId,
      title: title.trim(),
      remindAt: remindAt,
      notes: notes?.trim(),
      visitId: visitId,
    );

    final savedId = await _storage.saveReminder(
      id: id,
      reminder: reminder,
      isNew: isNew,
      resetPushSent: !isNew,
    );

    await FieldReminderNotificationService.cancelForReminder(savedId);
    final schedule = await FieldReminderNotificationService.scheduleIfEnabled(
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
    await FieldReminderNotificationService.cancelForReminder(id);
    await _storage.deleteReminder(id);
  }

  static Future<void> cancelLocalNotification(String id) =>
      FieldReminderNotificationService.cancelForReminder(id);
}
