import 'package:credit_calc_core/credit_calc_core.dart';

import '../models/field_reminder.dart';
import '../models/field_visit.dart';
import 'field_reminder_service.dart';
import 'field_visit_service.dart';
import 'installment_monitor_config_storage.dart';

enum InstallmentMonitorFollowUpMode {
  telefonico,
  domiciliare;

  String get label => switch (this) {
        InstallmentMonitorFollowUpMode.telefonico => 'Sollecito telefonico',
        InstallmentMonitorFollowUpMode.domiciliare => 'Visita domiciliare',
      };

  String get shortLabel => switch (this) {
        InstallmentMonitorFollowUpMode.telefonico => 'Telefonico',
        InstallmentMonitorFollowUpMode.domiciliare => 'Domiciliare',
      };

  static InstallmentMonitorFollowUpMode fromStorage(String? raw) =>
      raw == 'domiciliare'
          ? InstallmentMonitorFollowUpMode.domiciliare
          : InstallmentMonitorFollowUpMode.telefonico;
}

/// Pratica con rate registrate in provvigioni (stesso creditore + azienda).
class InstallmentMonitorPractice {
  const InstallmentMonitorPractice({
    required this.groupKey,
    required this.companyName,
    required this.creditorId,
    required this.creditorName,
    required this.installments,
  });

  final String groupKey;
  final String companyName;
  final String creditorId;
  final String creditorName;
  final List<CommissionEntryRecord> installments;

  int get totalRates => installments.length;
}

class InstallmentMonitorConfig {
  const InstallmentMonitorConfig({
    required this.id,
    required this.companyName,
    required this.creditorId,
    required this.creditorName,
    required this.ratesMonitored,
    required this.totalRates,
    required this.followUpMode,
    required this.reminderIds,
    required this.visitIds,
    required this.commissionEntryIds,
    required this.createdAt,
  });

  final String id;
  final String companyName;
  final String creditorId;
  final String creditorName;
  final int ratesMonitored;
  final int totalRates;
  final InstallmentMonitorFollowUpMode followUpMode;
  final List<String> reminderIds;
  final List<String> visitIds;
  final List<String> commissionEntryIds;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'companyName': companyName,
        'creditorId': creditorId,
        'creditorName': creditorName,
        'ratesMonitored': ratesMonitored,
        'totalRates': totalRates,
        'followUpMode': followUpMode.name,
        'reminderIds': reminderIds,
        'visitIds': visitIds,
        'commissionEntryIds': commissionEntryIds,
        'createdAt': createdAt.toIso8601String(),
      };

  factory InstallmentMonitorConfig.fromJson(Map<String, dynamic> json) {
    return InstallmentMonitorConfig(
      id: (json['id'] ?? '').toString(),
      companyName: (json['companyName'] ?? '').toString(),
      creditorId: (json['creditorId'] ?? '').toString(),
      creditorName: (json['creditorName'] ?? '').toString(),
      ratesMonitored: (json['ratesMonitored'] as num?)?.toInt() ?? 0,
      totalRates: (json['totalRates'] as num?)?.toInt() ?? 0,
      followUpMode: InstallmentMonitorFollowUpMode.fromStorage(
        json['followUpMode']?.toString(),
      ),
      reminderIds: [
        for (final id in (json['reminderIds'] as List? ?? const []))
          id.toString(),
      ],
      visitIds: [
        for (final id in (json['visitIds'] as List? ?? const [])) id.toString(),
      ],
      commissionEntryIds: [
        for (final id in (json['commissionEntryIds'] as List? ?? const []))
          id.toString(),
      ],
      createdAt: DateTime.tryParse('${json['createdAt']}') ?? DateTime.now(),
    );
  }
}

class InstallmentMonitorPlan {
  const InstallmentMonitorPlan({
    required this.ratesToMonitor,
    required this.followUpMode,
    this.visitAddress = '',
  });

  final int ratesToMonitor;
  final InstallmentMonitorFollowUpMode followUpMode;
  final String visitAddress;
}

/// Monitoraggio scadenze rate da piani esportati in provvigioni.
abstract final class InstallmentMonitorService {
  InstallmentMonitorService._();

  static const notesPrefix = 'rateizzo-monitor:';

  static List<InstallmentMonitorPractice> practicesFromEntries(
    List<CommissionEntryRecord> entries,
  ) {
    final grouped = <String, List<CommissionEntryRecord>>{};
    for (final entry in entries) {
      final company = CommissionCollectionsHelper.companyName(entry.data);
      if (company.isEmpty) continue;
      final creditorId = (entry.data['creditorId'] ?? '').toString();
      final key = '$creditorId::$company';
      grouped.putIfAbsent(key, () => []).add(entry);
    }

    final practices = <InstallmentMonitorPractice>[];
    for (final item in grouped.entries) {
      final installments = List<CommissionEntryRecord>.from(item.value)
        ..sort((a, b) {
          final da =
              CommissionCollectionsHelper.entryDate(a.data) ?? DateTime(1970);
          final db =
              CommissionCollectionsHelper.entryDate(b.data) ?? DateTime(1970);
          return da.compareTo(db);
        });
      if (installments.isEmpty) continue;

      final first = installments.first.data;
      practices.add(
        InstallmentMonitorPractice(
          groupKey: item.key,
          companyName: CommissionCollectionsHelper.companyName(first),
          creditorId: (first['creditorId'] ?? '').toString(),
          creditorName: CommissionCollectionsHelper.creditorName(first),
          installments: installments,
        ),
      );
    }

    practices.sort(
      (a, b) => a.companyName.toLowerCase().compareTo(
            b.companyName.toLowerCase(),
          ),
    );
    return practices;
  }

  static bool isRateizzoReminder(FieldReminder reminder) =>
      reminder.notes?.startsWith(notesPrefix) == true;

  static bool isRateizzoVisit(FieldVisit visit) =>
      visit.notes?.startsWith(notesPrefix) == true;

  static int upcomingTelefonicoCount(List<FieldReminder> reminders) {
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);
    final horizon = startOfToday.add(const Duration(days: 8));
    var count = 0;
    for (final reminder in reminders) {
      if (!isRateizzoReminder(reminder)) continue;
      final day = DateTime(
        reminder.remindAt.year,
        reminder.remindAt.month,
        reminder.remindAt.day,
      );
      if (day.isBefore(startOfToday)) continue;
      if (!day.isBefore(horizon)) continue;
      count++;
    }
    return count;
  }

  static int upcomingDomiciliareCount(List<FieldVisit> visits) {
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);
    final horizon = startOfToday.add(const Duration(days: 8));
    var count = 0;
    for (final visit in visits) {
      if (!isRateizzoVisit(visit)) continue;
      if (visit.status == FieldVisitStatus.cancelled) continue;
      final day = DateTime(
        visit.scheduledAt.year,
        visit.scheduledAt.month,
        visit.scheduledAt.day,
      );
      if (day.isBefore(startOfToday)) continue;
      if (!day.isBefore(horizon)) continue;
      count++;
    }
    return count;
  }

  static int upcomingAlertCount({
    required List<FieldReminder> reminders,
    required List<FieldVisit> visits,
  }) =>
      upcomingTelefonicoCount(reminders) + upcomingDomiciliareCount(visits);

  static int badgeCountFromReminders(List<FieldReminder> reminders) =>
      upcomingTelefonicoCount(reminders);

  static DateTime remindAtForCollection(DateTime collectionDate) => DateTime(
        collectionDate.year,
        collectionDate.month,
        collectionDate.day,
        9,
      );

  static Future<List<InstallmentMonitorConfig>> loadConfigs() =>
      InstallmentMonitorConfigStorage.instance.loadAll();

  static Future<void> _saveConfigs(List<InstallmentMonitorConfig> configs) =>
      InstallmentMonitorConfigStorage.instance.saveAll(configs);

  static Future<void> _removeTrackedItems(InstallmentMonitorConfig config) async {
    for (final reminderId in config.reminderIds) {
      await FieldReminderService.delete(reminderId);
    }
    for (final visitId in config.visitIds) {
      await FieldVisitService.delete(visitId);
    }
  }

  static String _entryNotes({
    required String monitorId,
    required String entryId,
    required int rateIndex,
    required int totalRates,
    required String dateLabel,
    required double amount,
  }) =>
      '$notesPrefix$monitorId:$entryId\n'
      'Rata $rateIndex/$totalRates · Scadenza PDR: $dateLabel · '
      '${CommissionCollectionsHelper.formatEuro(amount)}';

  static Future<InstallmentMonitorConfig> activate({
    required InstallmentMonitorPractice practice,
    required InstallmentMonitorPlan plan,
  }) async {
    final count = plan.ratesToMonitor.clamp(1, practice.totalRates);
    final selected = practice.installments.take(count).toList();
    final monitorId = DateTime.now().microsecondsSinceEpoch.toString();
    final reminderIds = <String>[];
    final visitIds = <String>[];

    final configs = await loadConfigs();
    final existing = configs
        .where(
          (c) =>
              c.creditorId == practice.creditorId &&
              c.companyName == practice.companyName,
        )
        .toList();
    for (final old in existing) {
      await _removeTrackedItems(old);
    }
    configs.removeWhere(
      (c) =>
          c.creditorId == practice.creditorId &&
          c.companyName == practice.companyName,
    );

    for (var i = 0; i < selected.length; i++) {
      final entry = selected[i];
      final collectionDate = CommissionCollectionsHelper.entryDate(entry.data);
      if (collectionDate == null) continue;

      final amount = CommissionCollectionsHelper.numField(
        entry.data,
        'amountCollected',
      );
      final dateLabel = CommissionCollectionsHelper.formatDate(collectionDate);
      final scheduledAt = remindAtForCollection(collectionDate);
      final notes = _entryNotes(
        monitorId: monitorId,
        entryId: entry.id,
        rateIndex: i + 1,
        totalRates: count,
        dateLabel: dateLabel,
        amount: amount,
      );

      if (plan.followUpMode == InstallmentMonitorFollowUpMode.telefonico) {
        final result = await FieldReminderService.save(
          title:
              'Sollecito telefonico: ${practice.companyName} '
              '(rata ${i + 1}/$count)',
          remindAt: scheduledAt,
          notes: notes,
        );
        reminderIds.add(result.id);
      } else {
        final visitId = await FieldVisitService.save(
          companyName: practice.companyName,
          address: plan.visitAddress.trim(),
          scheduledAt: scheduledAt,
          creditorId: practice.creditorId,
          creditorName: practice.creditorName,
          calculationId: entry.id,
          notes: notes,
        );
        visitIds.add(visitId);
      }
    }

    final config = InstallmentMonitorConfig(
      id: monitorId,
      companyName: practice.companyName,
      creditorId: practice.creditorId,
      creditorName: practice.creditorName,
      ratesMonitored: count,
      totalRates: practice.totalRates,
      followUpMode: plan.followUpMode,
      reminderIds: reminderIds,
      visitIds: visitIds,
      commissionEntryIds: selected.map((e) => e.id).toList(),
      createdAt: DateTime.now(),
    );
    configs.add(config);
    await _saveConfigs(configs);
    return config;
  }

  static Future<void> deactivate(String monitorId) async {
    final configs = await loadConfigs();
    InstallmentMonitorConfig? config;
    for (final item in configs) {
      if (item.id == monitorId) {
        config = item;
        break;
      }
    }
    if (config == null) return;

    await _removeTrackedItems(config);

    configs.removeWhere((c) => c.id == monitorId);
    await _saveConfigs(configs);
  }

  static Future<InstallmentMonitorConfig> update({
    required InstallmentMonitorConfig config,
    required InstallmentMonitorPractice practice,
    required InstallmentMonitorPlan plan,
  }) async {
    await _removeTrackedItems(config);

    final count = plan.ratesToMonitor.clamp(1, practice.totalRates);
    final selected = practice.installments.take(count).toList();
    final reminderIds = <String>[];
    final visitIds = <String>[];

    for (var i = 0; i < selected.length; i++) {
      final entry = selected[i];
      final collectionDate = CommissionCollectionsHelper.entryDate(entry.data);
      if (collectionDate == null) continue;

      final amount = CommissionCollectionsHelper.numField(
        entry.data,
        'amountCollected',
      );
      final dateLabel = CommissionCollectionsHelper.formatDate(collectionDate);
      final scheduledAt = remindAtForCollection(collectionDate);
      final notes = _entryNotes(
        monitorId: config.id,
        entryId: entry.id,
        rateIndex: i + 1,
        totalRates: count,
        dateLabel: dateLabel,
        amount: amount,
      );

      if (plan.followUpMode == InstallmentMonitorFollowUpMode.telefonico) {
        final result = await FieldReminderService.save(
          title:
              'Sollecito telefonico: ${practice.companyName} '
              '(rata ${i + 1}/$count)',
          remindAt: scheduledAt,
          notes: notes,
        );
        reminderIds.add(result.id);
      } else {
        final visitId = await FieldVisitService.save(
          companyName: practice.companyName,
          address: plan.visitAddress.trim(),
          scheduledAt: scheduledAt,
          creditorId: practice.creditorId,
          creditorName: practice.creditorName,
          calculationId: entry.id,
          notes: notes,
        );
        visitIds.add(visitId);
      }
    }

    final updated = InstallmentMonitorConfig(
      id: config.id,
      companyName: practice.companyName,
      creditorId: practice.creditorId,
      creditorName: practice.creditorName,
      ratesMonitored: count,
      totalRates: practice.totalRates,
      followUpMode: plan.followUpMode,
      reminderIds: reminderIds,
      visitIds: visitIds,
      commissionEntryIds: selected.map((e) => e.id).toList(),
      createdAt: config.createdAt,
    );

    final configs = await loadConfigs();
    final index = configs.indexWhere((c) => c.id == config.id);
    if (index >= 0) {
      configs[index] = updated;
    } else {
      configs.add(updated);
    }
    await _saveConfigs(configs);
    return updated;
  }

  static InstallmentMonitorConfig? configForPractice(
    InstallmentMonitorPractice practice,
    List<InstallmentMonitorConfig> configs,
  ) {
    for (final config in configs) {
      if (config.creditorId == practice.creditorId &&
          config.companyName == practice.companyName) {
        return config;
      }
    }
    return null;
  }
}
