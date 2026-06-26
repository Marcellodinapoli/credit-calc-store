import '../models/field_activity.dart';
import '../models/field_reminder.dart';
import '../models/field_visit.dart';
import 'firestore_itinerary_storage.dart';

/// Persistenza itinerario sul dispositivo (default).
abstract class ItineraryStorage {
  static ItineraryStorage instance = FirestoreItineraryStorage();

  Stream<List<FieldVisit>> watchAllVisits();

  Future<List<FieldVisit>> fetchAllVisits();

  Future<String> saveVisit({
    String? id,
    required FieldVisit visit,
    bool isNew,
    bool includePreVisitPushReset,
  });

  Future<void> deleteVisit(String id);

  Future<void> updateVisitStatus(String id, FieldVisitStatus status);

  Future<void> saveVisitRouteOrder(List<FieldVisit> ordered);

  Stream<List<FieldActivity>> watchAllActivities();

  Future<String> saveActivity({
    String? id,
    required FieldActivity activity,
    bool isNew,
  });

  Future<void> deleteActivity(String id);

  Stream<List<FieldReminder>> watchAllReminders();

  Future<List<FieldReminder>> fetchAllReminders();

  Future<String> saveReminder({
    String? id,
    required FieldReminder reminder,
    bool isNew,
    bool resetPushSent,
  });

  Future<void> deleteReminder(String id);
}
