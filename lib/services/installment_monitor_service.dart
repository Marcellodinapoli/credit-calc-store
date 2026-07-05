import 'package:credit_calc_core/credit_calc_core.dart';

import '../models/field_reminder.dart';
import '../models/field_visit.dart';
import '../offline/repository/credit_calc_repository.dart';
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
    this.pdrInstallments = const [],
  });

  final String groupKey;
  final String companyName;
  final String creditorId;
  final String creditorName;
  final List<CommissionEntryRecord> installments;
  final List<PdrInstallment> pdrInstallments;

  int get totalRates => pdrInstallments.isNotEmpty
      ? pdrInstallments.length
      : installments.length;
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

/// Dettagli PDR mostrati sulle card appuntamenti e promemoria.
class InstallmentMonitorPdrDetails {
  const InstallmentMonitorPdrDetails({
    required this.rateIndex,
    required this.totalRates,
    this.installmentAmount,
    this.pdrTotalAmount,
    this.pdrDevelopedAt,
  });

  final int rateIndex;
  final int totalRates;
  final double? installmentAmount;
  final double? pdrTotalAmount;
  final DateTime? pdrDevelopedAt;

  bool get hasData =>
      rateIndex > 0 &&
      totalRates > 0 &&
      (installmentAmount != null ||
          pdrTotalAmount != null ||
          pdrDevelopedAt != null);
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

  static Future<List<InstallmentMonitorPractice>> practicesFromEntriesAsync(
    List<CommissionEntryRecord> entries,
  ) async {
    final practices = practicesFromEntries(entries);
    if (practices.isEmpty) return practices;

    try {
      final schedules = await PdrScheduleStorage.instance.listSchedules();

      return [
        for (final practice in practices)
          InstallmentMonitorPractice(
            groupKey: practice.groupKey,
            companyName: practice.companyName,
            creditorId: practice.creditorId,
            creditorName: practice.creditorName,
            installments: practice.installments,
            pdrInstallments: _resolvePdrInstallments(
              practice: practice,
              schedules: schedules,
            ),
          ),
      ];
    } catch (_) {
      return [
        for (final practice in practices)
          InstallmentMonitorPractice(
            groupKey: practice.groupKey,
            companyName: practice.companyName,
            creditorId: practice.creditorId,
            creditorName: practice.creditorName,
            installments: practice.installments,
            pdrInstallments: _pdrInstallmentsFromEntries(practice.installments),
          ),
      ];
    }
  }

  static List<PdrInstallment> _resolvePdrInstallments({
    required InstallmentMonitorPractice practice,
    required List<PdrScheduleRecord> schedules,
  }) {
    final fromSchedule = _findSchedule(schedules, practice)?.installments;
    if (fromSchedule != null && fromSchedule.isNotEmpty) {
      return fromSchedule;
    }
    return _pdrInstallmentsFromEntries(practice.installments);
  }

  static PdrScheduleRecord? _findSchedule(
    List<PdrScheduleRecord> schedules,
    InstallmentMonitorPractice practice,
  ) {
    for (final schedule in schedules) {
      if (schedule.groupKey == practice.groupKey) {
        return schedule;
      }
    }

    final company = practice.companyName.trim().toLowerCase();
    if (company.isEmpty) return null;

    for (final schedule in schedules) {
      if (schedule.creditorId == practice.creditorId &&
          schedule.companyName.trim().toLowerCase() == company) {
        return schedule;
      }
    }
    return null;
  }

  static List<PdrInstallment> _pdrInstallmentsFromEntries(
    List<CommissionEntryRecord> entries,
  ) {
    for (final entry in entries) {
      final parsed = _pdrInstallmentsFromEntryData(entry.data);
      if (parsed.isNotEmpty) {
        return parsed;
      }
    }
    return const [];
  }

  static List<PdrInstallment> _pdrInstallmentsFromEntryData(
    Map<String, dynamic> data,
  ) {
    final raw = data['pdrInstallments'];
    if (raw is! List || raw.isEmpty) return const [];

    final installments = <PdrInstallment>[];
    for (var i = 0; i < raw.length; i++) {
      final item = raw[i];
      if (item is! Map) continue;
      installments.add(
        PdrInstallment.fromJson(Map<String, dynamic>.from(item)),
      );
    }
    installments.sort((a, b) => a.dueDate.compareTo(b.dueDate));
    return installments;
  }

  static bool isRateizzoReminder(FieldReminder reminder) =>
      reminder.notes?.startsWith(notesPrefix) == true;

  /// Note visibili in lista, senza il prefisso tecnico `rateizzo-monitor:…`.
  static String? rateizzoReminderVisibleNotes(FieldReminder reminder) {
    if (!isRateizzoReminder(reminder)) return null;
    final notes = reminder.notes;
    if (notes == null) return null;

    final visible = notes
        .split('\n')
        .where((line) => !line.trim().startsWith(notesPrefix))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .join('\n');
    return visible.isEmpty ? null : visible;
  }

  static bool isRateizzoVisit(FieldVisit visit) =>
      visit.notes?.startsWith(notesPrefix) == true;

  static Future<List<PdrScheduleRecord>>? _schedulesCache;

  static Future<List<PdrScheduleRecord>> _cachedSchedules() {
    _schedulesCache ??= PdrScheduleStorage.instance.listSchedules();
    return _schedulesCache!;
  }

  static ({int rateIndex, int totalRates, double? amount})? _parseRateFromNotes(
    String? notes,
  ) {
    if (notes == null) return null;
    for (final line in notes.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.startsWith(notesPrefix)) continue;
      final match = RegExp(
        r'^Rata (\d+)/(\d+) · Scadenza PDR: .+? · (.+)$',
      ).firstMatch(trimmed);
      if (match == null) continue;
      return (
        rateIndex: int.tryParse(match.group(1)!) ?? 0,
        totalRates: int.tryParse(match.group(2)!) ?? 0,
        amount: EuroFormat.parse(match.group(3)),
      );
    }
    return null;
  }

  static ({int rateIndex, int totalRates})? _parseRateFromTitle(String title) {
    final match = RegExp(r'\(rata (\d+)/(\d+)\)').firstMatch(title);
    if (match == null) return null;
    return (
      rateIndex: int.tryParse(match.group(1)!) ?? 0,
      totalRates: int.tryParse(match.group(2)!) ?? 0,
    );
  }

  static PdrInstallment? _matchInstallmentByDay(
    List<PdrInstallment> installments,
    DateTime when,
  ) {
    for (final installment in installments) {
      final due = installment.dueDate;
      if (due.year == when.year &&
          due.month == when.month &&
          due.day == when.day) {
        return installment;
      }
    }
    return null;
  }

  static PdrInstallment? _installmentAtIndex(
    List<PdrInstallment> installments,
    int rateIndex,
  ) {
    if (rateIndex <= 0) return null;
    for (final installment in installments) {
      if (installment.index == rateIndex) return installment;
    }
    if (rateIndex <= installments.length) {
      return installments[rateIndex - 1];
    }
    return null;
  }

  static Future<InstallmentMonitorPdrDetails?> resolvePdrDetailsForVisit(
    FieldVisit visit,
  ) async {
    final parsedNotes = _parseRateFromNotes(visit.notes);
    final schedules = await _cachedSchedules();

    PdrScheduleRecord? schedule;
    final creditorId = visit.creditorId?.trim() ?? '';
    final company = visit.companyName.trim();
    if (creditorId.isNotEmpty && company.isNotEmpty) {
      schedule = _findSchedule(
        schedules,
        InstallmentMonitorPractice(
          groupKey: '$creditorId::$company',
          companyName: company,
          creditorId: creditorId,
          creditorName: visit.creditorName ?? '',
          installments: const [],
        ),
      );
    }

    var installments = schedule?.installments ?? const <PdrInstallment>[];
    var developedAt = schedule?.createdAt;

    if (installments.isEmpty) {
      final entryId = visit.calculationId?.trim() ?? '';
      if (entryId.isNotEmpty) {
        final entry = await CreditCalcRepository.instance.getCalculation(entryId);
        if (entry != null) {
          installments = _pdrInstallmentsFromEntryData(entry.data);
        }
      }
    }

    if (installments.isEmpty) return null;

    final totalRates = parsedNotes?.totalRates ?? installments.length;
    var rateIndex = parsedNotes?.rateIndex ?? 0;
    var installmentAmount = parsedNotes?.amount;

    if (rateIndex <= 0) {
      final matched = _matchInstallmentByDay(installments, visit.scheduledAt);
      if (matched != null) {
        rateIndex = matched.index > 0
            ? matched.index
            : installments.indexOf(matched) + 1;
        installmentAmount ??= matched.amount;
      }
    }

    if (rateIndex <= 0) rateIndex = 1;
    installmentAmount ??=
        _installmentAtIndex(installments, rateIndex)?.amount;

    final monitored = await _ratesMonitoredForVisit(visit.id);
    final displayTotalRates =
        monitored != null && monitored > 0 ? monitored : totalRates;

    return InstallmentMonitorPdrDetails(
      rateIndex: rateIndex,
      totalRates: displayTotalRates,
      installmentAmount: installmentAmount,
      pdrTotalAmount: installments.fold<double>(0, (sum, i) => sum + i.amount),
      pdrDevelopedAt: developedAt,
    );
  }

  static Future<InstallmentMonitorPdrDetails?> resolvePdrDetailsForReminder(
    FieldReminder reminder,
  ) async {
    final parsedNotes = _parseRateFromNotes(reminder.notes);
    final parsedTitle = _parseRateFromTitle(reminder.title);
    final schedules = await _cachedSchedules();

    final company = _companyFromReminderTitle(reminder.title);
    final creditorId = await _creditorIdFromReminderNotes(reminder.notes);

    PdrScheduleRecord? schedule;
    if (creditorId != null &&
        creditorId.isNotEmpty &&
        company != null &&
        company.isNotEmpty) {
      schedule = _findSchedule(
        schedules,
        InstallmentMonitorPractice(
          groupKey: '$creditorId::$company',
          companyName: company,
          creditorId: creditorId,
          creditorName: '',
          installments: const [],
        ),
      );
    }

    var installments = schedule?.installments ?? const <PdrInstallment>[];
    final developedAt = schedule?.createdAt;

    if (installments.isEmpty) {
      final entryId = _entryIdFromReminderNotes(reminder.notes);
      if (entryId != null && entryId.isNotEmpty) {
        final entry = await CreditCalcRepository.instance.getCalculation(entryId);
        if (entry != null) {
          installments = _pdrInstallmentsFromEntryData(entry.data);
        }
      }
    }

    if (installments.isEmpty) return null;

    final totalRates =
        parsedNotes?.totalRates ?? parsedTitle?.totalRates ?? installments.length;
    var rateIndex = parsedNotes?.rateIndex ?? parsedTitle?.rateIndex ?? 0;
    var installmentAmount = parsedNotes?.amount;

    if (rateIndex <= 0) {
      final matched = _matchInstallmentByDay(installments, reminder.remindAt);
      if (matched != null) {
        rateIndex = matched.index > 0
            ? matched.index
            : installments.indexOf(matched) + 1;
        installmentAmount ??= matched.amount;
      }
    }

    if (rateIndex <= 0) rateIndex = 1;
    installmentAmount ??=
        _installmentAtIndex(installments, rateIndex)?.amount;

    final monitored = await _ratesMonitoredForReminder(reminder.id);
    final displayTotalRates =
        monitored != null && monitored > 0 ? monitored : totalRates;

    return InstallmentMonitorPdrDetails(
      rateIndex: rateIndex,
      totalRates: displayTotalRates,
      installmentAmount: installmentAmount,
      pdrTotalAmount: installments.fold<double>(0, (sum, i) => sum + i.amount),
      pdrDevelopedAt: developedAt,
    );
  }

  static Future<int?> _ratesMonitoredForVisit(String visitId) async {
    final configs = await loadConfigs();
    for (final config in configs) {
      if (config.visitIds.contains(visitId)) return config.ratesMonitored;
    }
    return null;
  }

  static Future<int?> _ratesMonitoredForReminder(String reminderId) async {
    final configs = await loadConfigs();
    for (final config in configs) {
      if (config.reminderIds.contains(reminderId)) return config.ratesMonitored;
    }
    return null;
  }

  static String? _companyFromReminderTitle(String title) {
    final match = RegExp(r'^Sollecito telefonico:\s*(.+?)\s*\(rata').firstMatch(
      title.trim(),
    );
    return match?.group(1)?.trim();
  }

  static String? _entryIdFromReminderNotes(String? notes) {
    if (notes == null || !notes.startsWith(notesPrefix)) return null;
    final firstLine = notes.split('\n').first.trim();
    final payload = firstLine.substring(notesPrefix.length);
    final parts = payload.split(':');
    if (parts.length < 2) return null;
    return parts.sublist(1).join(':').trim();
  }

  static Future<String?> _creditorIdFromReminderNotes(String? notes) async {
    final entryId = _entryIdFromReminderNotes(notes);
    if (entryId == null || entryId.isEmpty) return null;
    final entry = await CreditCalcRepository.instance.getCalculation(entryId);
    return (entry?.data['creditorId'] ?? '').toString().trim();
  }

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
    final monitorId = DateTime.now().microsecondsSinceEpoch.toString();
    final tracked = await _createTrackedItems(
      practice: practice,
      plan: plan,
      monitorId: monitorId,
      count: count,
    );
    final reminderIds = tracked.reminderIds;
    final visitIds = tracked.visitIds;

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
      commissionEntryIds: tracked.commissionEntryIds,
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
    final tracked = await _createTrackedItems(
      practice: practice,
      plan: plan,
      monitorId: config.id,
      count: count,
    );

    final updated = InstallmentMonitorConfig(
      id: config.id,
      companyName: practice.companyName,
      creditorId: practice.creditorId,
      creditorName: practice.creditorName,
      ratesMonitored: count,
      totalRates: practice.totalRates,
      followUpMode: plan.followUpMode,
      reminderIds: tracked.reminderIds,
      visitIds: tracked.visitIds,
      commissionEntryIds: tracked.commissionEntryIds,
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

  static Future<_TrackedMonitorItems> _createTrackedItems({
    required InstallmentMonitorPractice practice,
    required InstallmentMonitorPlan plan,
    required String monitorId,
    required int count,
  }) async {
    final reminderIds = <String>[];
    final visitIds = <String>[];
    final commissionEntryIds = <String>[];
    final linkedEntryId =
        practice.installments.isNotEmpty ? practice.installments.first.id : '';

    if (practice.pdrInstallments.isNotEmpty) {
      final selected = practice.pdrInstallments.take(count).toList();
      for (var i = 0; i < selected.length; i++) {
        final installment = selected[i];
        final collectionDate = installment.dueDate;
        final amount = installment.amount;
        final dateLabel = CommissionCollectionsHelper.formatDate(collectionDate);
        final scheduledAt = remindAtForCollection(collectionDate);
        final rateIndex = installment.index > 0 ? installment.index : i + 1;
        final notes = _entryNotes(
          monitorId: monitorId,
          entryId: linkedEntryId,
          rateIndex: rateIndex,
          totalRates: count,
          dateLabel: dateLabel,
          amount: amount,
        );

        if (plan.followUpMode == InstallmentMonitorFollowUpMode.telefonico) {
          final result = await FieldReminderService.save(
            title:
                'Sollecito telefonico: ${practice.companyName} '
                '(rata $rateIndex/$count)',
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
            calculationId: linkedEntryId,
            notes: notes,
          );
          visitIds.add(visitId);
        }
      }
      if (linkedEntryId.isNotEmpty) {
        commissionEntryIds.add(linkedEntryId);
      }
      return _TrackedMonitorItems(
        reminderIds: reminderIds,
        visitIds: visitIds,
        commissionEntryIds: commissionEntryIds,
      );
    }

    final selected = practice.installments.take(count).toList();
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
      commissionEntryIds.add(entry.id);
    }

    return _TrackedMonitorItems(
      reminderIds: reminderIds,
      visitIds: visitIds,
      commissionEntryIds: commissionEntryIds,
    );
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

class _TrackedMonitorItems {
  const _TrackedMonitorItems({
    required this.reminderIds,
    required this.visitIds,
    required this.commissionEntryIds,
  });

  final List<String> reminderIds;
  final List<String> visitIds;
  final List<String> commissionEntryIds;
}
