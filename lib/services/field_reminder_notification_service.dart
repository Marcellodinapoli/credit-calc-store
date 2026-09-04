import '../core/firestore_user_scope.dart';
import '../models/field_reminder.dart';
import 'field_reminder_service.dart';
import 'itinerary_notifications_service.dart';
import 'local_notifications_service.dart';
import 'product_notifications_service.dart';

class FieldReminderScheduleResult {
  const FieldReminderScheduleResult({
    required this.scheduled,
    this.issue,
    this.notifyAt,
  });

  final bool scheduled;
  final String? issue;
  final DateTime? notifyAt;
}

abstract final class FieldReminderNotificationService {
  /// Preavviso locale (allineato al push cloud ~5 min prima).
  static const Duration advance = Duration(minutes: 5);

  static int notificationIdFor(String reminderId) =>
      reminderId.hashCode & 0x7fffffff;

  /// Secondo avviso all'orario del promemoria (come le visite).
  static int atTimeNotificationIdFor(String reminderId) =>
      (notificationIdFor(reminderId) ^ 0x00A11A1D) & 0x7fffffff;

  static DateTime? resolveNotifyAt(DateTime remindAt) {
    if (!remindAt.isAfter(DateTime.now())) return null;

    final early = remindAt.subtract(advance);
    if (early.isAfter(DateTime.now())) return early;

    return DateTime.now().add(const Duration(seconds: 45));
  }

  static Future<FieldReminderScheduleResult> scheduleIfEnabled(
    FieldReminder reminder,
  ) async {
    final uid = FirestoreUserScope.uid;
    if (uid == null || reminder.id.isEmpty) {
      return const FieldReminderScheduleResult(
        scheduled: false,
        issue: 'Sessione non valida.',
      );
    }

    if (!reminder.isActiveForNotification) {
      await cancelForReminder(reminder.id);
      return const FieldReminderScheduleResult(scheduled: false);
    }

    final productEnabled = await ProductNotificationsService.loadEnabled(uid);
    final itineraryEnabled =
        await ItineraryNotificationsService.loadEnabled(uid);
    if (!productEnabled || !itineraryEnabled) {
      return const FieldReminderScheduleResult(
        scheduled: false,
        issue:
            'Attiva «Ricevi notifiche» e «Itinerario sul territorio» '
            'in Area personale → Notifiche.',
      );
    }

    final notifyAt = resolveNotifyAt(reminder.remindAt);
    if (notifyAt == null) {
      await cancelForReminder(reminder.id);
      return const FieldReminderScheduleResult(
        scheduled: false,
        issue: 'L\'orario del promemoria è già trascorso.',
      );
    }

    final hasPermission = await LocalNotificationsService.ensurePermission(
      allowPrompt: false,
    );
    if (!hasPermission) {
      return const FieldReminderScheduleResult(
        scheduled: false,
        issue:
            'Permesso notifiche non concesso. Attiva «Notifiche itinerario» '
            'in Area personale → Notifiche.',
      );
    }

    final timeLabel = _formatTime(reminder.remindAt);
    final notes = reminder.notes?.trim() ?? '';
    final preBody =
        notes.isNotEmpty ? notes : 'Scadenza alle $timeLabel';
    final atBody = notes.isNotEmpty
        ? '$notes · è ora ($timeLabel)'
        : 'È l\'orario del promemoria ($timeLabel)';

    try {
      await cancelForReminder(reminder.id);

      await LocalNotificationsService.scheduleItineraryReminder(
        id: notificationIdFor(reminder.id),
        title: reminder.title,
        body: preBody,
        when: notifyAt,
        payload: 'field_reminder:${reminder.id}',
      );

      final atTime = reminder.remindAt;
      if (atTime.isAfter(DateTime.now().add(const Duration(seconds: 90))) &&
          atTime.difference(notifyAt).inSeconds > 60) {
        await LocalNotificationsService.scheduleItineraryReminder(
          id: atTimeNotificationIdFor(reminder.id),
          title: reminder.title,
          body: atBody,
          when: atTime,
          payload: 'field_reminder:${reminder.id}',
        );
      }

      return FieldReminderScheduleResult(
        scheduled: true,
        notifyAt: notifyAt,
      );
    } catch (e) {
      return FieldReminderScheduleResult(
        scheduled: false,
        issue:
            'Impossibile programmare l\'avviso sul dispositivo. '
            'Verifica permesso notifiche e allarmi esatti per CreditCalc.',
      );
    }
  }

  static Future<void> cancelForReminder(String reminderId) async {
    if (reminderId.isEmpty) return;
    await LocalNotificationsService.cancelScheduled(
      notificationIdFor(reminderId),
    );
    await LocalNotificationsService.cancelScheduled(
      atTimeNotificationIdFor(reminderId),
    );
  }

  static Future<void> syncAllForCurrentUser() async {
    final uid = FirestoreUserScope.uid;
    if (uid == null) return;

    final productEnabled = await ProductNotificationsService.loadEnabled(uid);
    final itineraryEnabled =
        await ItineraryNotificationsService.loadEnabled(uid);
    if (!productEnabled || !itineraryEnabled) {
      await cancelAllForCurrentUser();
      return;
    }

    final reminders = await FieldReminderService.fetchAllForUserId(uid);
    for (final reminder in reminders) {
      if (!reminder.isActiveForNotification) {
        await cancelForReminder(reminder.id);
        continue;
      }
      await scheduleIfEnabled(reminder);
    }
  }

  static Future<void> cancelAllForCurrentUser() async {
    final uid = FirestoreUserScope.uid;
    if (uid == null) return;
    final reminders = await FieldReminderService.fetchAllForUserId(uid);
    for (final reminder in reminders) {
      await cancelForReminder(reminder.id);
    }
  }

  static String _formatTime(DateTime value) {
    final h = value.hour.toString().padLeft(2, '0');
    final m = value.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}
