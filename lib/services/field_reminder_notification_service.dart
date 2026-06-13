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
  static const Duration advance = Duration(minutes: 5);

  static int notificationIdFor(String reminderId) =>
      reminderId.hashCode & 0x7fffffff;

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
      return const FieldReminderScheduleResult(
        scheduled: false,
        issue: 'L\'orario del promemoria è già trascorso.',
      );
    }

    // Consenso già dato in Area personale → Notifiche: non richiedere di nuovo.
    final hasPermission = await _hasDeviceNotificationPermission();

    final timeLabel = _formatTime(reminder.remindAt);
    final body = reminder.notes?.trim().isNotEmpty == true
        ? reminder.notes!.trim()
        : 'Scadenza alle $timeLabel';

    try {
      await LocalNotificationsService.scheduleItineraryReminder(
        id: notificationIdFor(reminder.id),
        title: reminder.title,
        body: body,
        when: notifyAt,
        payload: reminder.id,
      );
      return FieldReminderScheduleResult(
        scheduled: true,
        notifyAt: notifyAt,
      );
    } catch (e) {
      final permissionHint = hasPermission
          ? ''
          : ' Verifica il permesso notifiche per CreditCalc '
              'nelle impostazioni del telefono.';
      return FieldReminderScheduleResult(
        scheduled: false,
        issue:
            'Impossibile programmare l\'avviso sul dispositivo.$permissionHint',
      );
    }
  }

  static Future<bool> _hasDeviceNotificationPermission() async {
    if (await LocalNotificationsService.hasPermission()) return true;
    return ProductNotificationsService.hasSystemPermission();
  }

  static Future<void> cancelForReminder(String reminderId) async {
    if (reminderId.isEmpty) return;
    await LocalNotificationsService.cancelScheduled(
      notificationIdFor(reminderId),
    );
  }

  static Future<void> syncAllForCurrentUser() async {
    final uid = FirestoreUserScope.uid;
    if (uid == null) return;

    final productEnabled = await ProductNotificationsService.loadEnabled(uid);
    final itineraryEnabled =
        await ItineraryNotificationsService.loadEnabled(uid);
    if (!productEnabled || !itineraryEnabled) return;

    final snap = await FieldReminderService.fetchAllForUser(uid);
    for (final reminder in snap) {
      await scheduleIfEnabled(reminder);
    }
  }

  static String _formatTime(DateTime value) {
    final h = value.hour.toString().padLeft(2, '0');
    final m = value.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}
