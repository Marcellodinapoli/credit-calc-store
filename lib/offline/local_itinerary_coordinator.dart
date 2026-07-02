import 'dart:async';

import 'package:credit_calc_core/credit_calc_core.dart';

import '../../services/field_reminder_notification_service.dart';
import '../../services/field_visit_notification_service.dart';
import '../../services/firestore_itinerary_storage.dart';
import '../../services/itinerary_storage.dart';
import 'develop_sync/develop_backoffice_pending_plan_repository.dart';
import 'develop_sync/develop_backoffice_pending_plan_storage.dart';
import 'develop_sync/develop_itinerary_repository.dart';
import 'develop_sync/develop_itinerary_storage.dart';
import 'develop_sync/develop_sync_sqlite_store.dart';
import 'services/local_data_cipher.dart';

/// Itinerario sul dispositivo (visite, attività, promemoria).
abstract final class LocalItineraryCoordinator {
  static DevelopSyncSqliteStore? _store;
  static DevelopItineraryRepository? _repository;
  static DevelopBackofficePendingPlanRepository? _backofficeRepository;
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
    _backofficeRepository = DevelopBackofficePendingPlanRepository(_store!);
    ItineraryStorage.instance = DevelopItineraryStorage(_repository!);
    BackofficePendingPlanStorage.instance =
        DevelopBackofficePendingPlanStorage(_backofficeRepository!);
    _active = true;
    MigratedDataFirestorePolicy.isLocalPrimary = () => _active;

    await LocalDataCipher.warmUp();

    unawaited(_repository!.backfillStableDateFieldsIfNeeded());
    unawaited(FieldVisitNotificationService.syncAllForCurrentUser());
    unawaited(FieldReminderNotificationService.syncAllForCurrentUser());
  }

  static Future<void> stop() async {
    if (!_active) return;
    MigratedDataFirestorePolicy.isLocalPrimary = null;
    ItineraryStorage.instance = FirestoreItineraryStorage();
    BackofficePendingPlanStorage.instance =
        FirestoreBackofficePendingPlanStorage();
    _repository = null;
    _backofficeRepository = null;
    _store = null;
    _active = false;
  }
}
