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
  /// Preavviso locale (allineato al push cloud ~30 min prima).
  static const Duration advance = Duration(minutes: 30);

  static int notificationIdFor(String visitId) =>
      (visitId.hashCode ^ 0x56495349) & 0x7fffffff;

  /// Secondo avviso all'orario dell'appuntamento (come i promemoria "al momento").
  static int atTimeNotificationIdFor(String visitId) =>
      (notificationIdFor(visitId) ^ 0x00A77A1E) & 0x7fffffff;

  static DateTime? resolveNotifyAt(DateTime scheduledAt) {
    if (!scheduledAt.isAfter(DateTime.now())) return null;

    final early = scheduledAt.subtract(advance);
    if (early.isAfter(DateTime.now())) return early;

    // Appuntamento entro 30 minuti: avvisa quasi subito.
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
      await cancelForVisit(visit.id);
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
      await cancelForVisit(visit.id);
      return const FieldVisitScheduleResult(
        scheduled: false,
        issue: 'L\'orario della visita è già trascorso.',
      );
    }

    // Come i promemoria: verifica permesso prima di programmare.
    final hasPermission = await LocalNotificationsService.ensurePermission(
      allowPrompt: false,
    );
    if (!hasPermission) {
      return const FieldVisitScheduleResult(
        scheduled: false,
        issue:
            'Permesso notifiche non concesso. Attiva «Notifiche itinerario» '
            'in Area personale → Notifiche.',
      );
    }

    final timeLabel = _formatTime(visit.scheduledAt);
    final company = visit.companyName.trim().isEmpty
        ? 'Visita in programma'
        : visit.companyName.trim();
    final address = visit.address.trim();
    final preBody = address.isEmpty
        ? 'Appuntamento alle $timeLabel'
        : '$address · $timeLabel';
    final atBody = address.isEmpty
        ? 'È l\'orario dell\'appuntamento ($timeLabel)'
        : '$address · è ora ($timeLabel)';

    try {
      await cancelForVisit(visit.id);

      await LocalNotificationsService.scheduleItineraryReminder(
        id: notificationIdFor(visit.id),
        title: company,
        body: preBody,
        when: notifyAt,
        payload: 'field_visit:${visit.id}',
      );

      // Secondo avviso all'orario visita (se ancora nel futuro e distinto).
      final atTime = visit.scheduledAt;
      if (atTime.isAfter(DateTime.now().add(const Duration(seconds: 90))) &&
          atTime.difference(notifyAt).inSeconds > 60) {
        await LocalNotificationsService.scheduleItineraryReminder(
          id: atTimeNotificationIdFor(visit.id),
          title: company,
          body: atBody,
          when: atTime,
          payload: 'field_visit:${visit.id}',
        );
      }

      return FieldVisitScheduleResult(
        scheduled: true,
        notifyAt: notifyAt,
      );
    } catch (e) {
      return FieldVisitScheduleResult(
        scheduled: false,
        issue:
            'Impossibile programmare l\'avviso sul dispositivo. '
            'Verifica permesso notifiche e allarmi esatti per CreditCalc.',
      );
    }
  }

  static Future<void> cancelForVisit(String visitId) async {
    if (visitId.isEmpty) return;
    await LocalNotificationsService.cancelScheduled(notificationIdFor(visitId));
    await LocalNotificationsService.cancelScheduled(
      atTimeNotificationIdFor(visitId),
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

    final visits = await FieldVisitService.fetchAllForUserId(uid);
    for (final visit in visits) {
      if (visit.status != FieldVisitStatus.planned) {
        await cancelForVisit(visit.id);
        continue;
      }
      await scheduleIfEnabled(visit);
    }
  }

  static Future<void> cancelAllForCurrentUser() async {
    final uid = FirestoreUserScope.uid;
    if (uid == null) return;
    final visits = await FieldVisitService.fetchAllForUserId(uid);
    for (final visit in visits) {
      await cancelForVisit(visit.id);
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
