import '../offline/develop_sync/develop_itinerary_storage.dart';
import '../offline/local_itinerary_coordinator.dart';
import 'itinerary_storage.dart';

/// Storage itinerario locale-first (SQLite) quando il coordinatore è attivo.
abstract final class ItineraryStorageAccess {
  static ItineraryStorage get instance {
    final repo = LocalItineraryCoordinator.repository;
    if (LocalItineraryCoordinator.isActive && repo != null) {
      return DevelopItineraryStorage(repo);
    }
    return ItineraryStorage.instance;
  }
}
