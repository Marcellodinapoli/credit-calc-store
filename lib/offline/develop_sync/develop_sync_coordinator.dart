import 'dart:async';

import 'package:credit_calc_core/credit_calc_core.dart';
import 'package:flutter/foundation.dart';

import '../../services/firestore_itinerary_storage.dart';
import '../../services/field_reminder_notification_service.dart';
import '../../services/field_visit_notification_service.dart';
import '../../services/installment_monitor_config_storage.dart';
import '../../services/itinerary_storage.dart';
import '../local_itinerary_coordinator.dart';
import 'develop_backoffice_pending_plan_repository.dart';
import 'develop_backoffice_pending_plan_storage.dart';
import 'develop_installment_monitor_config_storage.dart';
import 'develop_installment_monitor_repository.dart';
import 'develop_itinerary_repository.dart';
import 'develop_itinerary_storage.dart';
import 'develop_pdr_schedule_storage.dart';
import 'develop_public_usage_totals_sync.dart';
import 'installment_monitor_prefs_migration.dart';
import 'develop_sync_crypto.dart';
import 'develop_sync_engine.dart';
import 'develop_sync_service.dart';
import 'develop_sync_sqlite_store.dart';
import 'models/develop_local_collection.dart';

/// Avvio sync multi-dispositivo: dati con ragione sociale solo in locale + relay cifrato.
abstract final class DevelopSyncCoordinator {
  static DevelopSyncSqliteStore? _store;
  static DevelopItineraryRepository? _itineraryRepository;
  static DevelopBackofficePendingPlanRepository? _backofficeRepository;
  static DevelopInstallmentMonitorRepository? _installmentMonitorRepository;
  static bool _active = false;

  static bool get isActive => _active;
  static DevelopSyncSqliteStore? get store => _store;

  static Future<bool> startIfNeeded({
    required String userId,
    VoidCallback? onDataChanged,
  }) async {
    if (userId.isEmpty) return false;
    if (_active && _store?.userId == userId) return true;

    await stop();

    if (LocalItineraryCoordinator.isActive &&
        LocalItineraryCoordinator.store?.userId == userId) {
      _store = LocalItineraryCoordinator.store;
    } else {
      _store = DevelopSyncSqliteStore(userId);
    }
    if (!LocalItineraryCoordinator.isActive) {
      _itineraryRepository = DevelopItineraryRepository(_store!);
      ItineraryStorage.instance =
          DevelopItineraryStorage(_itineraryRepository!);
    } else {
      _itineraryRepository = LocalItineraryCoordinator.repository;
    }
    _backofficeRepository = DevelopBackofficePendingPlanRepository(_store!);
    _installmentMonitorRepository =
        DevelopInstallmentMonitorRepository(_store!);
    if (_itineraryRepository != null) {
      ItineraryStorage.instance =
          DevelopItineraryStorage(_itineraryRepository!);
    }
    BackofficePendingPlanStorage.instance =
        DevelopBackofficePendingPlanStorage(_backofficeRepository!);
    PdrScheduleStorage.instance = DevelopPdrScheduleStorage(_store!);
    InstallmentMonitorConfigStorage.instance =
        DevelopInstallmentMonitorConfigStorage(_installmentMonitorRepository!);
    await InstallmentMonitorPrefsMigration.migrateIfNeeded(_store!);

    DevelopSyncService.instance.onDataChanged = () {
      onDataChanged?.call();
      unawaited(FieldVisitNotificationService.syncAllForCurrentUser());
      unawaited(FieldReminderNotificationService.syncAllForCurrentUser());
    };
    MigratedDataFirestorePolicy.isLocalPrimary = () =>
        LocalItineraryCoordinator.isActive || _active;
    await DevelopSyncService.instance.start(_store!);
    _active = true;

    await DevelopPublicUsageTotalsSync.syncFromLocalStore(userId);
    await FieldVisitNotificationService.syncAllForCurrentUser();
    await FieldReminderNotificationService.syncAllForCurrentUser();
    return true;
  }

  static Future<void> stop() async {
    await DevelopSyncService.instance.stop();
    if (_active) {
      MigratedDataFirestorePolicy.isLocalPrimary = () =>
          LocalItineraryCoordinator.isActive;
      DevelopSyncCrypto.clearCache(_store?.userId);
    }
    if (!LocalItineraryCoordinator.isActive) {
      ItineraryStorage.instance = FirestoreItineraryStorage();
    }
    if (LocalItineraryCoordinator.isActive &&
        LocalItineraryCoordinator.store != null) {
      final repo = DevelopBackofficePendingPlanRepository(
        LocalItineraryCoordinator.store!,
      );
      BackofficePendingPlanStorage.instance =
          DevelopBackofficePendingPlanStorage(repo);
      PdrScheduleStorage.instance =
          DevelopPdrScheduleStorage(LocalItineraryCoordinator.store!);
    } else {
      BackofficePendingPlanStorage.instance =
          FirestoreBackofficePendingPlanStorage();
      PdrScheduleStorage.instance = FirestorePdrScheduleStorage();
    }
    InstallmentMonitorConfigStorage.instance =
        InMemoryInstallmentMonitorConfigStorage();
    _itineraryRepository = null;
    _backofficeRepository = null;
    _installmentMonitorRepository = null;
    _store = null;
    _active = false;
  }

  static void notifyLocalMutation(
    String collection,
    String id, {
    required bool deleted,
  }) {
    if (!_active || _store == null) return;
    final parsed = DevelopLocalCollectionCodec.fromStorageKey(collection);
    if (parsed == null) return;
    _store!.notifyLocalMutation(parsed, id, deleted: deleted);
  }

  static Future<DevelopSyncRunResult?> syncNow() =>
      DevelopSyncService.instance.syncNow();
}
