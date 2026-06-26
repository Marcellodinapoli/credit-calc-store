import '../../services/field_reminder_notification_service.dart';
import '../../services/field_visit_notification_service.dart';
import '../../services/firestore_itinerary_storage.dart';
import '../../services/itinerary_storage.dart';
import 'develop_sync/develop_itinerary_repository.dart';
import 'develop_sync/develop_itinerary_storage.dart';
import 'develop_sync/develop_sync_sqlite_store.dart';

/// Itinerario sul dispositivo (visite, attività, promemoria).
abstract final class LocalItineraryCoordinator {
  static DevelopSyncSqliteStore? _store;
  static DevelopItineraryRepository? _repository;
  static bool _active = false;

  static bool get isActive => _active;
  static DevelopSyncSqliteStore? get store => _store;
  static DevelopItineraryRepository? get repository => _repository;

  static Future<void> start(String userId) async {
    if (userId.isEmpty) return;
    if (_active && _store?.userId == userId) return;

    await stop();

    _store = DevelopSyncSqliteStore(userId);
    _repository = DevelopItineraryRepository(_store!);
    ItineraryStorage.instance = DevelopItineraryStorage(_repository!);
    _active = true;

    await FieldVisitNotificationService.syncAllForCurrentUser();
    await FieldReminderNotificationService.syncAllForCurrentUser();
  }

  static Future<void> stop() async {
    if (!_active) return;
    ItineraryStorage.instance = FirestoreItineraryStorage();
    _repository = null;
    _store = null;
    _active = false;
  }
}
