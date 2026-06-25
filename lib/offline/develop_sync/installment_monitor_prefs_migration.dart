import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/installment_monitor_service.dart';
import 'develop_installment_monitor_repository.dart';
import 'develop_sync_sqlite_store.dart';

abstract final class InstallmentMonitorPrefsMigration {
  static const _legacyKeys = [
    'installment_monitor_configs_v2',
    'installment_monitor_configs_v1',
  ];

  static Future<void> migrateIfNeeded(DevelopSyncSqliteStore store) async {
    final repo = DevelopInstallmentMonitorRepository(store);
    final existing = await repo.loadAll();
    if (existing.isNotEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    for (final key in _legacyKeys) {
      final raw = prefs.getString(key);
      if (raw == null || raw.isEmpty) continue;

      try {
        final decoded = jsonDecode(raw);
        if (decoded is! List) continue;
        final configs = <InstallmentMonitorConfig>[];
        for (final item in decoded) {
          if (item is Map) {
            configs.add(
              InstallmentMonitorConfig.fromJson(
                Map<String, dynamic>.from(item),
              ),
            );
          }
        }
        if (configs.isEmpty) continue;

        await repo.saveAll(configs);
        await prefs.remove(key);
        debugPrint(
          'InstallmentMonitorPrefsMigration: migrate ${configs.length} config.',
        );
        return;
      } catch (_) {}
    }
  }
}
