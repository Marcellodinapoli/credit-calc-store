import 'package:flutter/foundation.dart';

/// Badge «Itinerario» (nav) + alert su card Appuntamenti / Promemoria da notifiche.
final class ItineraryNavBadgeNotifier {
  ItineraryNavBadgeNotifier._();

  static final ItineraryNavBadgeNotifier instance =
      ItineraryNavBadgeNotifier._();

  /// Pallino sulla voce di menu Itinerario (mobile/desktop).
  final ValueNotifier<bool> pending = ValueNotifier(false);

  /// Alert sulla card Appuntamenti (notifica visita ricevuta).
  final ValueNotifier<bool> appointmentsPending = ValueNotifier(false);

  /// Alert sulla card Promemoria (notifica reminder ricevuta).
  final ValueNotifier<bool> remindersPending = ValueNotifier(false);

  /// Hint one-shot (es. attivazione monitoraggio rate).
  bool _navHint = false;

  void markPending() {
    _navHint = true;
    _recompute();
  }

  void markAppointments() {
    appointmentsPending.value = true;
    _recompute();
  }

  void markReminders() {
    remindersPending.value = true;
    _recompute();
  }

  void markFromNotificationType(String type) {
    switch (type.trim()) {
      case 'field_visit':
        markAppointments();
      case 'field_reminder':
        markReminders();
      default:
        break;
    }
  }

  void clearAppointments() {
    if (!appointmentsPending.value) return;
    appointmentsPending.value = false;
    _recompute();
  }

  void clearReminders() {
    if (!remindersPending.value) return;
    remindersPending.value = false;
    _recompute();
  }

  /// Apre la tab Itinerario: toglie solo l'hint monitoraggio, non gli alert notifica.
  void clear() {
    if (!_navHint) return;
    _navHint = false;
    _recompute();
  }

  void _recompute() {
    pending.value =
        _navHint || appointmentsPending.value || remindersPending.value;
  }
}
