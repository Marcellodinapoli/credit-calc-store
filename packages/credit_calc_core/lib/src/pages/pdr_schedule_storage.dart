import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../data/migrated_data_firestore_policy.dart';
import 'package:flutter/foundation.dart';

import '../core/euro_format.dart';
import 'repayment_plan_commission_export.dart';

/// Singola rata prevista dal piano di rientro (calendario PDR).
class PdrInstallment {
  const PdrInstallment({
    required this.index,
    required this.dueDate,
    required this.amount,
  });

  final int index;
  final DateTime dueDate;
  final double amount;

  Map<String, dynamic> toJson() => {
        'index': index,
        'dueDateMs': dueDate.millisecondsSinceEpoch,
        'amount': amount,
      };

  factory PdrInstallment.fromJson(Map<String, dynamic> json) {
    final dueMs = json['dueDateMs'];
    return PdrInstallment(
      index: (json['index'] as num?)?.toInt() ?? 1,
      dueDate: dueMs is num
          ? DateTime.fromMillisecondsSinceEpoch(dueMs.toInt())
          : DateTime.tryParse('${json['dueDate']}') ?? DateTime.now(),
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
    );
  }
}

/// Calendario completo PDR per una pratica (creditore + azienda).
class PdrScheduleRecord {
  const PdrScheduleRecord({
    required this.id,
    required this.companyName,
    required this.creditorId,
    required this.creditorName,
    required this.planSource,
    required this.installments,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String companyName;
  final String creditorId;
  final String creditorName;
  final String planSource;
  final List<PdrInstallment> installments;
  final DateTime createdAt;
  final DateTime updatedAt;

  String get groupKey => '$creditorId::$companyName';

  int get totalRates => installments.length;

  Map<String, dynamic> toPayload() => {
        'companyName': companyName,
        'creditorId': creditorId,
        'creditorName': creditorName,
        'planSource': planSource,
        'installments': installments.map((i) => i.toJson()).toList(),
        'createdAtMs': createdAt.millisecondsSinceEpoch,
        'updatedAtMs': updatedAt.millisecondsSinceEpoch,
      };

  factory PdrScheduleRecord.fromStored(String id, Map<String, dynamic> data) {
    final rawInstallments = data['installments'];
    final installments = <PdrInstallment>[];
    if (rawInstallments is List) {
      for (var i = 0; i < rawInstallments.length; i++) {
        final item = rawInstallments[i];
        if (item is! Map) continue;
        final map = Map<String, dynamic>.from(item);
        if (!map.containsKey('index')) {
          map['index'] = i + 1;
        }
        installments.add(PdrInstallment.fromJson(map));
      }
    }
    installments.sort((a, b) => a.dueDate.compareTo(b.dueDate));

    return PdrScheduleRecord(
      id: id,
      companyName: (data['companyName'] ?? '').toString(),
      creditorId: (data['creditorId'] ?? '').toString(),
      creditorName: (data['creditorName'] ?? '').toString(),
      planSource: (data['planSource'] ?? 'standard_repayment').toString(),
      installments: installments,
      createdAt: _readDate(data['createdAtMs'] ?? data['createdAt']),
      updatedAt: _readDate(data['updatedAtMs'] ?? data['updatedAt']),
    );
  }

  static DateTime _readDate(dynamic raw) {
    if (raw is Timestamp) return raw.toDate();
    if (raw is num) return DateTime.fromMillisecondsSinceEpoch(raw.toInt());
    return DateTime.tryParse('$raw') ?? DateTime.now();
  }
}

/// Persistenza calendari PDR per Monitora rateizzo.
abstract class PdrScheduleStorage {
  static PdrScheduleStorage instance = FirestorePdrScheduleStorage();

  Stream<List<PdrScheduleRecord>> watchSchedules();

  Future<List<PdrScheduleRecord>> listSchedules();

  Future<PdrScheduleRecord> upsertForPractice({
    required String companyName,
    required String creditorId,
    required String creditorName,
    required String planSource,
    required List<CommissionInstallmentPayment> installments,
  });

  static String practiceDocId(String creditorId, String companyName) =>
      '$creditorId::${companyName.trim()}';

  static List<PdrInstallment> installmentsFromPayments(
    List<CommissionInstallmentPayment> payments,
  ) {
    final out = <PdrInstallment>[];
    for (var i = 0; i < payments.length; i++) {
      final payment = payments[i];
      if (payment.amount <= 0.009) continue;
      out.add(
        PdrInstallment(
          index: i + 1,
          dueDate: DateTime(
            payment.date.year,
            payment.date.month,
            payment.date.day,
          ),
          amount: payment.amount,
        ),
      );
    }
    return out;
  }

  static Future<void> saveAfterPlanExport({
    required String companyName,
    required String creditorId,
    required String creditorName,
    required String planSource,
    required List<CommissionInstallmentPayment> installments,
  }) async {
    if (installments.isEmpty) return;
    try {
      await instance.upsertForPractice(
        companyName: companyName,
        creditorId: creditorId,
        creditorName: creditorName,
        planSource: planSource,
        installments: installments,
      );
    } catch (e, st) {
      debugPrint('PdrScheduleStorage.saveAfterPlanExport: $e\n$st');
    }
  }
}

class FirestorePdrScheduleStorage implements PdrScheduleStorage {
  CollectionReference<Map<String, dynamic>> _collection(String userId) =>
      FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('pdr_schedules');

  String? get _userId => FirebaseAuth.instance.currentUser?.uid;

  @override
  Stream<List<PdrScheduleRecord>> watchSchedules() {
    MigratedDataFirestorePolicy.assertFirestoreAccessAllowed();
    return FirebaseAuth.instance.authStateChanges().asyncExpand((user) {
      if (user == null) return Stream.value(const <PdrScheduleRecord>[]);
      return _collection(user.uid).snapshots().map(
            (snap) => [
              for (final doc in snap.docs)
                PdrScheduleRecord.fromStored(doc.id, doc.data()),
            ],
          );
    });
  }

  @override
  Future<List<PdrScheduleRecord>> listSchedules() async {
    MigratedDataFirestorePolicy.assertFirestoreAccessAllowed();
    final userId = _userId;
    if (userId == null) return [];
    final snap = await _collection(userId).get();
    return [
      for (final doc in snap.docs)
        PdrScheduleRecord.fromStored(doc.id, doc.data()),
    ];
  }

  @override
  Future<PdrScheduleRecord> upsertForPractice({
    required String companyName,
    required String creditorId,
    required String creditorName,
    required String planSource,
    required List<CommissionInstallmentPayment> installments,
  }) async {
    MigratedDataFirestorePolicy.assertFirestoreAccessAllowed();
    final userId = _userId;
    if (userId == null) {
      throw StateError('Sessione scaduta');
    }

    final parsed = PdrScheduleStorage.installmentsFromPayments(installments);
    if (parsed.isEmpty) {
      throw StateError('Nessuna rata nel calendario PDR');
    }

    final docId = PdrScheduleStorage.practiceDocId(creditorId, companyName);
    final ref = _collection(userId).doc(docId);
    final existing = await ref.get();
    final now = DateTime.now();
    final createdAt = existing.exists
        ? PdrScheduleRecord.fromStored(docId, existing.data()!).createdAt
        : now;

    final payload = {
      'userId': userId,
      'companyName': companyName.trim(),
      'creditorId': creditorId,
      'creditorName': creditorName.trim(),
      'planSource': planSource,
      'installments': parsed.map((i) => i.toJson()).toList(),
      'totalAmount': parsed.fold<double>(0, (sum, i) => sum + i.amount),
      'rateCount': parsed.length,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': FieldValue.serverTimestamp(),
      'createdAtMs': createdAt.millisecondsSinceEpoch,
      'updatedAtMs': now.millisecondsSinceEpoch,
    };

    await ref.set(payload, SetOptions(merge: true));

    return PdrScheduleRecord(
      id: docId,
      companyName: companyName.trim(),
      creditorId: creditorId,
      creditorName: creditorName.trim(),
      planSource: planSource,
      installments: parsed,
      createdAt: createdAt,
      updatedAt: now,
    );
  }
}

String pdrInstallmentLabel(PdrInstallment installment) {
  final date = installment.dueDate;
  final dateLabel =
      '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/'
      '${date.year}';
  return 'Rata ${installment.index}: $dateLabel · ${EuroFormat.format(installment.amount)}';
}
