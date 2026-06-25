import '../../models/field_activity.dart';
import '../../models/field_reminder.dart';
import '../../models/field_visit.dart';
import '../../services/itinerary_storage.dart';
import 'develop_itinerary_repository.dart';

class DevelopItineraryStorage implements ItineraryStorage {
  DevelopItineraryStorage(this._repository);

  final DevelopItineraryRepository _repository;

  @override
  Stream<List<FieldVisit>> watchAllVisits() => _repository.watchVisits();

  @override
  Future<List<FieldVisit>> fetchAllVisits() => _repository.listVisits();

  @override
  Future<String> saveVisit({
    String? id,
    required FieldVisit visit,
    bool isNew = false,
    bool includePreVisitPushReset = false,
  }) {
    return _repository.saveVisit(
      id: id,
      visit: visit,
      isNew: isNew,
      extra: includePreVisitPushReset ? {'preVisitPushSent': false} : const {},
    );
  }

  @override
  Future<void> deleteVisit(String id) => _repository.deleteVisit(id);

  @override
  Future<void> updateVisitStatus(String id, FieldVisitStatus status) async {
    final existing = await _repository.getVisit(id);
    if (existing == null) return;
    await _repository.saveVisit(
      id: id,
      visit: existing.copyWith(status: status),
      isNew: false,
    );
  }

  @override
  Future<void> saveVisitRouteOrder(List<FieldVisit> ordered) async {
    for (var i = 0; i < ordered.length; i++) {
      await _repository.saveVisit(
        id: ordered[i].id,
        visit: ordered[i].copyWith(routeOrder: i),
        isNew: false,
      );
    }
  }

  @override
  Stream<List<FieldActivity>> watchAllActivities() =>
      _repository.watchActivities();

  @override
  Future<String> saveActivity({
    String? id,
    required FieldActivity activity,
    bool isNew = false,
  }) {
    return _repository.saveActivity(
      id: id,
      activity: activity,
      isNew: isNew,
    );
  }

  @override
  Future<void> deleteActivity(String id) => _repository.deleteActivity(id);

  @override
  Stream<List<FieldReminder>> watchAllReminders() =>
      _repository.watchReminders();

  @override
  Future<List<FieldReminder>> fetchAllReminders() =>
      _repository.listReminders();

  @override
  Future<String> saveReminder({
    String? id,
    required FieldReminder reminder,
    bool isNew = false,
    bool resetPushSent = false,
  }) {
    return _repository.saveReminder(
      id: id,
      reminder: reminder,
      isNew: isNew,
      resetPushSent: resetPushSent,
    );
  }

  @override
  Future<void> deleteReminder(String id) => _repository.deleteReminder(id);
}
