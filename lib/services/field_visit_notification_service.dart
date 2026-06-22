import '../core/firestore_user_scope.dart';
import '../models/field_visit.dart';
import 'field_visit_service.dart';
import 'itinerary_notifications_service.dart';
import 'local_notifications_service.dart';
import 'product_notifications_service.dart';

class FieldVisitScheduleResult {
  const FieldVisitScheduleResult({
    required this.scheduled,
    this.issue,
    this.notifyAt,
  });

  final bool scheduled;
  final String? issue;
  final DateTime? notifyAt;
}

abstract final class FieldVisitNotificationService {
  static const Duration advance = Duration(minutes: 30);

  static int notificationIdFor(String visitId) =>
      (visitId.hashCode ^ 0x56495349) & 0x7fffffff;

  static DateTime? resolveNotifyAt(DateTime scheduledAt) {
    if (!scheduledAt.isAfter(DateTime.now())) return null;

    final early = scheduledAt.subtract(advance);
    if (early.isAfter(DateTime.now())) return early;

    return DateTime.now().add(const Duration(seconds: 45));
  }

  static Future<FieldVisitScheduleResult> scheduleIfEnabled(
    FieldVisit visit,
  ) async {
    if (visit.id.isEmpty) {
      return const FieldVisitScheduleResult(
        scheduled: false,
        issue: 'Visita non valida.',
      );
    }

    if (visit.status != FieldVisitStatus.planned) {
      return const FieldVisitScheduleResult(scheduled: false);
    }

    final uid = FirestoreUserScope.uid;
    if (uid == null) {
      return const FieldVisitScheduleResult(
        scheduled: false,
        issue: 'Sessione non valida.',
      );
    }

    final productEnabled = await ProductNotificationsService.loadEnabled(uid);
    final itineraryEnabled =
        await ItineraryNotificationsService.loadEnabled(uid);
    if (!productEnabled || !itineraryEnabled) {
      return const FieldVisitScheduleResult(
        scheduled: false,
        issue:
            'Attiva «Ricevi notifiche» e «Itinerario sul territorio» '
            'in Area personale → Notifiche.',
      );
    }

    final notifyAt = resolveNotifyAt(visit.scheduledAt);
    if (notifyAt == null) {
      return const FieldVisitScheduleResult(
        scheduled: false,
        issue: 'L\'orario della visita è già trascorso.',
      );
    }

    final hasPermission = await _hasDeviceNotificationPermission();
    final timeLabel = _formatTime(visit.scheduledAt);
    final company = visit.companyName.trim().isEmpty
        ? 'Visita in programma'
        : visit.companyName.trim();
    final address = visit.address.trim();
    final body = address.isEmpty
        ? 'Appuntamento alle $timeLabel'
        : '$address · $timeLabel';

    try {
      await LocalNotificationsService.scheduleItineraryReminder(
        id: notificationIdFor(visit.id),
        title: company,
        body: body,
        when: notifyAt,
        payload: visit.id,
      );
      return FieldVisitScheduleResult(
        scheduled: true,
        notifyAt: notifyAt,
      );
    } catch (e) {
      final permissionHint = hasPermission
          ? ''
          : ' Verifica il permesso notifiche per CreditCalc '
              'nelle impostazioni del telefono.';
      return FieldVisitScheduleResult(
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

  static Future<void> cancelForVisit(String visitId) async {
    if (visitId.isEmpty) return;
    await LocalNotificationsService.cancelScheduled(notificationIdFor(visitId));
  }

  static Future<void> syncAllForCurrentUser() async {
    final uid = FirestoreUserScope.uid;
    if (uid == null) return;

    final productEnabled = await ProductNotificationsService.loadEnabled(uid);
    final itineraryEnabled =
        await ItineraryNotificationsService.loadEnabled(uid);
    if (!productEnabled || !itineraryEnabled) return;

    final visits = await FieldVisitService.fetchAllForUser(uid);
    for (final visit in visits) {
      if (visit.status != FieldVisitStatus.planned) {
        await cancelForVisit(visit.id);
        continue;
      }
      await scheduleIfEnabled(visit);
    }
  }

  static String _formatTime(DateTime value) {
    final d = value.day.toString().padLeft(2, '0');
    final m = value.month.toString().padLeft(2, '0');
    final h = value.hour.toString().padLeft(2, '0');
    final min = value.minute.toString().padLeft(2, '0');
    return '$d/$m/${value.year} $h:$min';
  }
}
