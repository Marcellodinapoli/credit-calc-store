import '../../../services/installment_monitor_service.dart';
import 'develop_sync_sqlite_store.dart';
import 'models/develop_local_collection.dart';

class DevelopInstallmentMonitorRepository {
  DevelopInstallmentMonitorRepository(this._store);

  final DevelopSyncSqliteStore _store;

  Future<List<InstallmentMonitorConfig>> loadAll() async {
    final rows = await _store.recordsForCollection(
      DevelopLocalCollection.installmentMonitorConfigs,
    );
    final configs = <InstallmentMonitorConfig>[];
    for (final row in rows) {
      try {
        configs.add(InstallmentMonitorConfig.fromJson(row.payload));
      } catch (_) {}
    }
    configs.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return configs;
  }

  Future<void> saveAll(List<InstallmentMonitorConfig> configs) async {
    final existing = await _store.recordsForCollection(
      DevelopLocalCollection.installmentMonitorConfigs,
    );
    final keepIds = configs.map((c) => c.id).toSet();

    for (final row in existing) {
      if (!keepIds.contains(row.id)) {
        await _store.deleteRecord(
          collection: DevelopLocalCollection.installmentMonitorConfigs,
          id: row.id,
        );
      }
    }

    for (final config in configs) {
      await _store.upsertRecord(
        collection: DevelopLocalCollection.installmentMonitorConfigs,
        id: config.id,
        payload: config.toJson(),
      );
    }
  }
}
