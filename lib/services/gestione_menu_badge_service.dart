import 'package:flutter/foundation.dart';

import '../models/field_activity.dart';
import '../models/field_reminder.dart';
import '../models/field_visit.dart';
import 'read_state_service.dart';

/// Chiavi allineate a Planet (`MenuItem.name`) per stato condiviso su Firestore.
enum GestioneMenuBadgeKey {
  oggi('calcGestione'),
  appointments('calcAppointments'),
  activities('calcActivities'),
  reminders('calcReminders');

  const GestioneMenuBadgeKey(this.storageKey);
  final String storageKey;
}

/// Badge pallino rosso sul menu Gestione per impegni previsti oggi.
abstract final class GestioneMenuBadgeService {
  static final ValueNotifier<int> changes = ValueNotifier(0);

  static String todayKey([DateTime? day]) {
    final d = day ?? DateTime.now();
    return '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
  }

  static bool isSameCalendarDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static bool hasTodayAppointments(List<FieldVisit> visits, DateTime today) =>
      visits.any(
        (v) =>
            v.status != FieldVisitStatus.cancelled &&
            isSameCalendarDay(v.scheduledAt, today),
      );

  static bool hasTodayActivities(List<FieldActivity> activities) =>
      activities.any((a) => !a.completed);

  static bool hasTodayReminders(List<FieldReminder> reminders, DateTime today) =>
      reminders.any((r) => isSameCalendarDay(r.remindAt, today));

  static bool hasTodayContentFor(
    GestioneMenuBadgeKey key, {
    required List<FieldVisit> visits,
    required List<FieldActivity> activities,
    required List<FieldReminder> reminders,
    DateTime? today,
  }) {
    final day = today ?? DateTime.now();
    return switch (key) {
      GestioneMenuBadgeKey.oggi =>
        hasTodayAppointments(visits, day) ||
            hasTodayActivities(activities) ||
            hasTodayReminders(reminders, day),
      GestioneMenuBadgeKey.appointments =>
        hasTodayAppointments(visits, day),
      GestioneMenuBadgeKey.activities => hasTodayActivities(activities),
      GestioneMenuBadgeKey.reminders =>
        hasTodayReminders(reminders, day),
    };
  }

  static bool shouldShowBadge(
    GestioneMenuBadgeKey key, {
    required Map<String, String> viewedDays,
    required List<FieldVisit> visits,
    required List<FieldActivity> activities,
    required List<FieldReminder> reminders,
    DateTime? today,
  }) {
    if (!hasTodayContentFor(
      key,
      visits: visits,
      activities: activities,
      reminders: reminders,
      today: today,
    )) {
      return false;
    }
    return viewedDays[key.storageKey] != todayKey(today);
  }

  static bool shouldShowGestioneSectionBadge({
    required Map<String, String> viewedDays,
    required List<FieldVisit> visits,
    required List<FieldActivity> activities,
    required List<FieldReminder> reminders,
    DateTime? today,
  }) =>
      GestioneMenuBadgeKey.values
          .where((key) => key != GestioneMenuBadgeKey.oggi)
          .any(
            (key) => shouldShowBadge(
              key,
              viewedDays: viewedDays,
              visits: visits,
              activities: activities,
              reminders: reminders,
              today: today,
            ),
          );

  static Future<void> markViewed(GestioneMenuBadgeKey key) async {
    await ReadStateService.setGestioneMenuViewedDay(
      key.storageKey,
      todayKey(),
    );
    changes.value++;
  }
}
