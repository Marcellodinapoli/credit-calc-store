import '../models/field_visit.dart';
import '../offline/repository/credit_calc_repository.dart';
import '../pages/creditcalc/commission_collections_shared.dart';
import 'field_reminder_service.dart';
import 'field_visit_service.dart';
import 'installment_monitor_config_storage.dart';
import 'installment_monitor_service.dart' show InstallmentMonitorConfig;

/// Mantiene allineati nome debitore e creditore tra provvigioni, appuntamenti
/// e monitoraggio rate collegati dallo stesso creditore/pratica.
abstract final class PracticeDataPropagationService {
  PracticeDataPropagationService._();

  static String creditorDisplayName(Map<String, dynamic> data) {
    final clientName = (data['clientName'] ?? '').toString().trim();
    if (clientName.isNotEmpty) return clientName;

    final name = (data['name'] ?? data['displayLabel'] ?? '').toString().trim();
    return name;
  }

  static Future<void> afterCreditorSaved({
    required String creditorId,
    required Map<String, dynamic> data,
    Map<String, dynamic>? previous,
  }) async {
    if (creditorId.isEmpty) return;

    final creditorName = creditorDisplayName(data);
    final previousName =
        previous != null ? creditorDisplayName(previous) : null;
    if (creditorName.isNotEmpty && creditorName != previousName) {
      await _propagateCreditorName(
        creditorId: creditorId,
        creditorName: creditorName,
      );
    }

    final newAddress = (data['visitAddress'] ?? '').toString().trim();
    final oldAddress = (previous?['visitAddress'] ?? '').toString().trim();
    if (newAddress.isNotEmpty && newAddress != oldAddress) {
      await _propagateCreditorVisitAddress(
        creditorId: creditorId,
        newAddress: newAddress,
        previousAddress: oldAddress,
      );
    }
  }

  static Future<void> afterCommissionEntrySaved({
    required String entryId,
    required Map<String, dynamic> data,
    Map<String, dynamic>? previous,
  }) async {
    if ((data['type'] ?? '') != 'commission_entry') return;

    final companyName = CommissionCollectionsHelper.companyName(data);
    final creditorId = (data['creditorId'] ?? '').toString();
    final creditorName = CommissionCollectionsHelper.creditorName(data);

    final oldCompany = previous != null
        ? CommissionCollectionsHelper.companyName(previous)
        : '';
    final oldCreditorName = previous != null
        ? CommissionCollectionsHelper.creditorName(previous)
        : '';

    await _patchVisitsByCalculationId(
      entryId,
      companyName: companyName,
      creditorName: creditorName.isNotEmpty ? creditorName : null,
      creditorId: creditorId.isNotEmpty ? creditorId : null,
    );

    if (creditorId.isNotEmpty &&
        oldCompany.isNotEmpty &&
        companyName.isNotEmpty &&
        oldCompany != companyName) {
      await _propagatePracticeRename(
        creditorId: creditorId,
        oldCompanyName: oldCompany,
        newCompanyName: companyName,
        creditorName: creditorName,
        excludeCalculationId: entryId,
      );
    } else if (creditorName.isNotEmpty &&
        oldCreditorName.isNotEmpty &&
        creditorName != oldCreditorName) {
      await _patchVisitsByCalculationId(
        entryId,
        creditorName: creditorName,
      );
    }
  }

  static Future<void> afterFieldVisitSaved({
    required FieldVisit visit,
    FieldVisit? previous,
  }) async {
    final calculationId = visit.calculationId?.trim();
    if (calculationId != null &&
        calculationId.isNotEmpty &&
        visit.companyName.trim().isNotEmpty) {
      final record = await CreditCalcRepository.instance.getCalculation(
        calculationId,
      );
      if (record != null) {
        final currentCompany = CommissionCollectionsHelper.companyName(
          record.data,
        );
        if (visit.companyName.trim() != currentCompany) {
          await CreditCalcRepository.instance.saveCalculation(
            id: calculationId,
            data: {'companyName': visit.companyName.trim()},
            isNew: false,
            skipPracticePropagation: true,
          );
        }
      }
    }

    if (previous == null) return;

    final creditorId = visit.creditorId?.trim() ?? '';
    final oldCompany = previous.companyName.trim();
    final newCompany = visit.companyName.trim();

    if (creditorId.isNotEmpty &&
        oldCompany.isNotEmpty &&
        newCompany.isNotEmpty &&
        oldCompany != newCompany) {
      await _propagatePracticeRename(
        creditorId: creditorId,
        oldCompanyName: oldCompany,
        newCompanyName: newCompany,
        creditorName: visit.creditorName ?? '',
        excludeVisitId: visit.id,
      );
    }
  }

  static Future<void> _propagateCreditorName({
    required String creditorId,
    required String creditorName,
  }) async {
    final calculations = await CreditCalcRepository.instance
        .getCalculationRecords();
    for (final record in calculations) {
      final data = record.data;
      if ((data['type'] ?? '') != 'commission_entry') continue;
      if ((data['creditorId'] ?? '').toString() != creditorId) continue;
      if (CommissionCollectionsHelper.creditorName(data) == creditorName) {
        continue;
      }
      await CreditCalcRepository.instance.saveCalculation(
        id: record.id,
        data: {'creditorName': creditorName},
        isNew: false,
        skipPracticePropagation: true,
      );
    }

    final visits = await FieldVisitService.fetchAllForUser();
    for (final visit in visits) {
      if (visit.creditorId != creditorId) continue;
      if ((visit.creditorName ?? '') == creditorName) continue;
      await _patchVisit(
        visit,
        creditorName: creditorName,
      );
    }

    await _patchInstallmentMonitorConfigs(
      creditorId: creditorId,
      creditorName: creditorName,
    );
  }

  static Future<void> _propagateCreditorVisitAddress({
    required String creditorId,
    required String newAddress,
    required String previousAddress,
  }) async {
    final visits = await FieldVisitService.fetchAllForUser();
    for (final visit in visits) {
      if (visit.creditorId != creditorId) continue;
      final current = visit.address.trim();
      if (current.isNotEmpty &&
          previousAddress.isNotEmpty &&
          current != previousAddress) {
        continue;
      }
      if (current == newAddress) continue;
      await FieldVisitService.save(
        id: visit.id,
        companyName: visit.companyName,
        address: newAddress,
        scheduledAt: visit.scheduledAt,
        status: visit.status,
        latitude: visit.latitude,
        longitude: visit.longitude,
        creditorId: visit.creditorId,
        creditorName: visit.creditorName,
        calculationId: visit.calculationId,
        notes: visit.notes,
        routeOrder: visit.routeOrder,
        geocodeIfNeeded: true,
        skipPracticePropagation: true,
      );
    }
  }

  static Future<void> _propagatePracticeRename({
    required String creditorId,
    required String oldCompanyName,
    required String newCompanyName,
    required String creditorName,
    String? excludeCalculationId,
    String? excludeVisitId,
  }) async {
    final calculations = await CreditCalcRepository.instance
        .getCalculationRecords();
    for (final record in calculations) {
      if (record.id == excludeCalculationId) continue;
      final data = record.data;
      if ((data['type'] ?? '') != 'commission_entry') continue;
      if ((data['creditorId'] ?? '').toString() != creditorId) continue;
      if (CommissionCollectionsHelper.companyName(data) != oldCompanyName) {
        continue;
      }
      final patch = <String, dynamic>{'companyName': newCompanyName};
      if (creditorName.isNotEmpty) {
        patch['creditorName'] = creditorName;
      }
      await CreditCalcRepository.instance.saveCalculation(
        id: record.id,
        data: patch,
        isNew: false,
        skipPracticePropagation: true,
      );
    }

    final visits = await FieldVisitService.fetchAllForUser();
    for (final visit in visits) {
      if (visit.id == excludeVisitId) continue;
      if (visit.creditorId != creditorId) continue;
      if (visit.companyName.trim() != oldCompanyName) continue;
      await _patchVisit(
        visit,
        companyName: newCompanyName,
        creditorName: creditorName.isNotEmpty ? creditorName : null,
      );
    }

    await _patchInstallmentMonitorConfigs(
      creditorId: creditorId,
      oldCompanyName: oldCompanyName,
      newCompanyName: newCompanyName,
      creditorName: creditorName.isNotEmpty ? creditorName : null,
    );
  }

  static Future<void> _patchVisitsByCalculationId(
    String calculationId, {
    String? companyName,
    String? creditorName,
    String? creditorId,
  }) async {
    if (companyName == null && creditorName == null && creditorId == null) {
      return;
    }

    final visits = await FieldVisitService.fetchAllForUser();
    for (final visit in visits) {
      if (visit.calculationId != calculationId) continue;
      await _patchVisit(
        visit,
        companyName: companyName,
        creditorName: creditorName,
      );
    }
  }

  static Future<void> _patchVisit(
    FieldVisit visit, {
    String? companyName,
    String? creditorName,
  }) async {
    final nextCompany = companyName?.trim();
    final nextCreditorName = creditorName?.trim();
    final companyChanged =
        nextCompany != null && nextCompany != visit.companyName.trim();
    final creditorChanged = nextCreditorName != null &&
        nextCreditorName != (visit.creditorName ?? '').trim();
    if (!companyChanged && !creditorChanged) return;

    await FieldVisitService.save(
      id: visit.id,
      companyName: nextCompany ?? visit.companyName,
      address: visit.address,
      scheduledAt: visit.scheduledAt,
      status: visit.status,
      latitude: visit.latitude,
      longitude: visit.longitude,
      creditorId: visit.creditorId,
      creditorName: creditorChanged ? nextCreditorName : visit.creditorName,
      calculationId: visit.calculationId,
      notes: visit.notes,
      routeOrder: visit.routeOrder,
      geocodeIfNeeded: false,
      skipPracticePropagation: true,
    );
  }

  static Future<void> _patchInstallmentMonitorConfigs({
    required String creditorId,
    String? oldCompanyName,
    String? newCompanyName,
    String? creditorName,
  }) async {
    final configs = await InstallmentMonitorConfigStorage.instance.loadAll();
    var changed = false;
    final updated = <InstallmentMonitorConfig>[];

    for (final config in configs) {
      if (config.creditorId != creditorId) {
        updated.add(config);
        continue;
      }

      var nextCompany = config.companyName;
      var nextCreditor = config.creditorName;
      var configChanged = false;

      if (oldCompanyName != null &&
          newCompanyName != null &&
          config.companyName == oldCompanyName) {
        nextCompany = newCompanyName;
        configChanged = true;
      }
      if (creditorName != null &&
          creditorName.isNotEmpty &&
          config.creditorName != creditorName) {
        nextCreditor = creditorName;
        configChanged = true;
      }

      if (!configChanged) {
        updated.add(config);
        continue;
      }

      changed = true;
      final patched = InstallmentMonitorConfig(
        id: config.id,
        companyName: nextCompany,
        creditorId: config.creditorId,
        creditorName: nextCreditor,
        ratesMonitored: config.ratesMonitored,
        totalRates: config.totalRates,
        followUpMode: config.followUpMode,
        reminderIds: config.reminderIds,
        visitIds: config.visitIds,
        commissionEntryIds: config.commissionEntryIds,
        createdAt: config.createdAt,
      );
      updated.add(patched);

      if (oldCompanyName != null &&
          newCompanyName != null &&
          oldCompanyName != newCompanyName) {
        await _renameTrackedReminderTitles(
          patched,
          oldCompanyName: oldCompanyName,
          newCompanyName: newCompanyName,
        );
      }
    }

    if (changed) {
      await InstallmentMonitorConfigStorage.instance.saveAll(updated);
    }
  }

  static Future<void> _renameTrackedReminderTitles(
    InstallmentMonitorConfig config, {
    required String oldCompanyName,
    required String newCompanyName,
  }) async {
    final reminders = await FieldReminderService.fetchAllForUser();
    final byId = {for (final r in reminders) r.id: r};

    for (final reminderId in config.reminderIds) {
      final reminder = byId[reminderId];
      if (reminder == null) continue;
      if (!reminder.title.contains(oldCompanyName)) continue;

      await FieldReminderService.save(
        id: reminder.id,
        title: reminder.title.replaceFirst(oldCompanyName, newCompanyName),
        remindAt: reminder.remindAt,
        notes: reminder.notes,
        visitId: reminder.visitId,
      );
    }
  }
}
