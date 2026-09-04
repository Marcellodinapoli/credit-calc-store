import '../core/firestore_user_scope.dart';
import '../models/field_reminder.dart';
import 'field_reminder_notification_service.dart';
import 'itinerary_storage.dart';
import 'itinerary_storage_access.dart';

class FieldReminderSaveResult {
  const FieldReminderSaveResult({
    required this.id,
    required this.schedule,
  });

  final String id;
  final FieldReminderScheduleResult schedule;
}

abstract final class FieldReminderService {
  static ItineraryStorage get _storage => ItineraryStorageAccess.instance;

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
    FieldReminderStatus status = FieldReminderStatus.planned,
    String? notes,
    String? visitId,
  }) async {
    final userId = FirestoreUserScope.uid;
    if (userId == null) throw StateError('Utente non autenticato');

    final isNew = id == null || id.isEmpty;
    FieldReminder? previous;
    if (!isNew) {
      final existing = await _storage.fetchAllReminders();
      for (final item in existing) {
        if (item.id == id) {
          previous = item;
          break;
        }
      }
    }

    final timeChanged = previous != null &&
        previous.remindAt.millisecondsSinceEpoch !=
            remindAt.millisecondsSinceEpoch;

    final reminder = FieldReminder(
      id: id ?? '',
      userId: userId,
      title: title.trim(),
      remindAt: remindAt,
      status: status,
      notes: notes?.trim(),
      visitId: visitId,
    );

    // Come le visite: reset push solo se nuovo o orario cambiato.
    // Completato/Annullato non deve riarmare il push cloud.
    final savedId = await _storage.saveReminder(
      id: id,
      reminder: reminder,
      isNew: isNew,
      resetPushSent: isNew || timeChanged,
    );

    await FieldReminderNotificationService.cancelForReminder(savedId);
    final schedule = status == FieldReminderStatus.planned
        ? await FieldReminderNotificationService.scheduleIfEnabled(
            FieldReminder(
              id: savedId,
              userId: userId,
              title: reminder.title,
              remindAt: remindAt,
              status: status,
              notes: reminder.notes,
              visitId: visitId,
            ),
          )
        : const FieldReminderScheduleResult(scheduled: false);

    return FieldReminderSaveResult(id: savedId, schedule: schedule);
  }

  static Future<void> updateStatus(
    String id,
    FieldReminderStatus status,
  ) async {
    final reminders = await _storage.fetchAllReminders();
    FieldReminder? current;
    for (final reminder in reminders) {
      if (reminder.id == id) {
        current = reminder;
        break;
      }
    }
    if (current == null) return;

    await save(
      id: current.id,
      title: current.title,
      remindAt: current.remindAt,
      status: status,
      notes: current.notes,
      visitId: current.visitId,
    );
  }

  static Future<void> delete(String id) async {
    await FieldReminderNotificationService.cancelForReminder(id);
    await _storage.deleteReminder(id);
  }

  static Future<void> cancelLocalNotification(String id) =>
      FieldReminderNotificationService.cancelForReminder(id);
}
