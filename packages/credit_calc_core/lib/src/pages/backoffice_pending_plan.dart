import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../core/theme/app_form_fields.dart';
import 'backoffice_pending_plan_storage.dart';

enum BackofficePendingPlanType {
  repayment('repayment', 'Piano di rientro'),
  balanceWriteOff('balance_write_off', 'Saldo e stralcio');

  const BackofficePendingPlanType(this.storageKey, this.label);

  final String storageKey;
  final String label;

  static BackofficePendingPlanType? fromStorageKey(String? raw) {
    if (raw == null) return null;
    for (final type in values) {
      if (type.storageKey == raw) return type;
    }
    return null;
  }
}

enum BackofficeAcceptedVia {
  manual('manual', 'manualmente'),
  commission('commission', 'tramite incasso in provvigioni');

  const BackofficeAcceptedVia(this.storageKey, this.label);

  final String storageKey;
  final String label;

  static BackofficeAcceptedVia? fromStorageKey(String? raw) {
    if (raw == null) return null;
    for (final via in values) {
      if (via.storageKey == raw) return via;
    }
    return null;
  }
}

class BackofficeSummaryRow {
  final String label;
  final String value;
  final bool highlight;
  final String? note;
  final String? valueSuffix;
  final String? valueSuffixColor;

  const BackofficeSummaryRow({
    required this.label,
    required this.value,
    this.highlight = false,
    this.note,
    this.valueSuffix,
    this.valueSuffixColor,
  });

  Map<String, dynamic> toMap() => {
        'label': label,
        'value': value,
        'highlight': highlight,
        if (note != null) 'note': note,
        if (valueSuffix != null) 'valueSuffix': valueSuffix,
        if (valueSuffixColor != null) 'valueSuffixColor': valueSuffixColor,
      };

  factory BackofficeSummaryRow.fromMap(Map<String, dynamic> map) {
    return BackofficeSummaryRow(
      label: (map['label'] ?? '').toString(),
      value: (map['value'] ?? '').toString(),
      highlight: map['highlight'] == true,
      note: map['note']?.toString(),
      valueSuffix: map['valueSuffix']?.toString(),
      valueSuffixColor: map['valueSuffixColor']?.toString(),
    );
  }
}

class BackofficePendingPlan {
  final String id;
  final BackofficePendingPlanType type;
  final String creditorId;
  final String creditorName;
  final DateTime submittedAt;
  final DateTime updatedAt;
  final Map<String, dynamic> formData;
  final List<BackofficeSummaryRow> summaryRows;
  final List<String> commissionDocIds;
  final DateTime? acceptedAt;
  final BackofficeAcceptedVia? acceptedVia;
  final DateTime? modifiedAt;
  final String? companyName;

  const BackofficePendingPlan({
    required this.id,
    required this.type,
    required this.creditorId,
    required this.creditorName,
    required this.submittedAt,
    required this.updatedAt,
    required this.formData,
    required this.summaryRows,
    this.commissionDocIds = const [],
    this.acceptedAt,
    this.acceptedVia,
    this.modifiedAt,
    this.companyName,
  });

  bool get isAccepted => acceptedAt != null;

  int get daysWaiting {
    final now = DateTime.now();
    final start = DateTime(submittedAt.year, submittedAt.month, submittedAt.day);
    final today = DateTime(now.year, now.month, now.day);
    return today.difference(start).inDays;
  }

  bool get hasCommissionExport => commissionDocIds.isNotEmpty;

  Map<String, dynamic> toStoredMap({
    bool isCreate = false,
    DateTime? now,
  }) {
    final timestamp = now ?? DateTime.now();
    return {
      'type': type.storageKey,
      'creditorId': creditorId,
      'creditorName': creditorName,
      if (isCreate) 'submittedAt': Timestamp.fromDate(timestamp),
      'updatedAt': Timestamp.fromDate(timestamp),
      'formData': formData,
      'summaryRows': summaryRows.map((row) => row.toMap()).toList(),
      'commissionDocIds': commissionDocIds,
      if (companyName != null && companyName!.isNotEmpty)
        'companyName': companyName,
      if (acceptedAt != null) 'acceptedAt': Timestamp.fromDate(acceptedAt!),
      if (acceptedVia != null) 'acceptedVia': acceptedVia!.storageKey,
      if (modifiedAt != null) 'modifiedAt': Timestamp.fromDate(modifiedAt!),
    };
  }

  factory BackofficePendingPlan.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    return BackofficePendingPlan.fromStored(doc.id, doc.data() ?? {});
  }

  factory BackofficePendingPlan.fromStored(
    String id,
    Map<String, dynamic> data,
  ) {
    final summaryRaw = data['summaryRows'];
    final rows = <BackofficeSummaryRow>[];
    if (summaryRaw is List) {
      for (final item in summaryRaw) {
        if (item is Map) {
          rows.add(
            BackofficeSummaryRow.fromMap(Map<String, dynamic>.from(item)),
          );
        }
      }
    }

    final commissionRaw = data['commissionDocIds'];
    final commissionIds = <String>[];
    if (commissionRaw is List) {
      for (final item in commissionRaw) {
        final id = item?.toString().trim();
        if (id != null && id.isNotEmpty) commissionIds.add(id);
      }
    }

    return BackofficePendingPlan(
      id: id,
      type: BackofficePendingPlanType.fromStorageKey(data['type']?.toString()) ??
          BackofficePendingPlanType.repayment,
      creditorId: (data['creditorId'] ?? '').toString(),
      creditorName: (data['creditorName'] ?? '').toString(),
      submittedAt: _readTimestamp(data['submittedAt']) ?? DateTime.now(),
      updatedAt: _readTimestamp(data['updatedAt']) ?? DateTime.now(),
      formData: Map<String, dynamic>.from(
        (data['formData'] as Map?)?.cast<String, dynamic>() ?? {},
      ),
      summaryRows: rows,
      commissionDocIds: commissionIds,
      acceptedAt: _readTimestamp(data['acceptedAt']),
      acceptedVia: BackofficeAcceptedVia.fromStorageKey(
        data['acceptedVia']?.toString(),
      ),
      modifiedAt: _readTimestamp(data['modifiedAt']),
      companyName: (data['companyName'] ?? '').toString().trim().isEmpty
          ? null
          : (data['companyName'] ?? '').toString().trim(),
    );
  }

  static DateTime? _readTimestamp(dynamic raw) {
    if (raw is Timestamp) return raw.toDate();
    return null;
  }
}

class BackofficePendingSaveResult {
  final String? id;
  final String? errorMessage;

  const BackofficePendingSaveResult({this.id, this.errorMessage});

  bool get ok => id != null && id!.isNotEmpty;
}

abstract final class BackofficePendingPlanService {
  static BackofficePendingPlanStorage get _storage =>
      BackofficePendingPlanStorage.instance;

  static Stream<List<BackofficePendingPlan>> watchAll() =>
      _storage.watchAll();

  static Future<BackofficePendingSaveResult> save({
    String? existingId,
    required BackofficePendingPlanType type,
    required String creditorId,
    required String creditorName,
    required Map<String, dynamic> formData,
    required List<BackofficeSummaryRow> summaryRows,
    List<String> commissionDocIds = const [],
    String? companyName,
  }) {
    return _storage.save(
      existingId: existingId,
      type: type,
      creditorId: creditorId,
      creditorName: creditorName,
      formData: formData,
      summaryRows: summaryRows,
      commissionDocIds: commissionDocIds,
      companyName: companyName,
    );
  }

  static Future<void> delete(String id) => _storage.delete(id);

  static Future<void> updateCommissionDocIds(
    String id,
    List<String> docIds,
  ) =>
      _storage.updateCommissionDocIds(id, docIds);

  static Future<void> markAcceptedManual(String id) =>
      _storage.markAcceptedManual(id);
}

/// Richiede la ragione sociale debitore prima di salvare in Riscontro backoffice.
Future<String?> showBackofficeCompanyNameDialog(
  BuildContext context, {
  String? initialValue,
}) async {
  final controller = TextEditingController(text: initialValue ?? '');

  final result = await showDialog<String>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: const Text('Ragione sociale'),
        content: TextField(
          controller: controller,
          textCapitalization: TextCapitalization.words,
          autofocus: true,
          decoration: appFormFieldDecoration(
            'Ragione sociale debitore',
          ).copyWith(
            hintText: 'Nome committente / debitore',
          ),
          onSubmitted: (value) {
            final name = value.trim();
            if (name.isEmpty) return;
            Navigator.pop(dialogContext, name);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isEmpty) return;
              Navigator.pop(dialogContext, name);
            },
            child: const Text('Conferma'),
          ),
        ],
      );
    },
  );

  controller.dispose();
  return result?.trim().isEmpty == true ? null : result?.trim();
}
