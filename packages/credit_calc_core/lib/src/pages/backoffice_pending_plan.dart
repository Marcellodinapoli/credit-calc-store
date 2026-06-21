import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
  });

  bool get isAccepted => acceptedAt != null;

  int get daysWaiting {
    final now = DateTime.now();
    final start = DateTime(submittedAt.year, submittedAt.month, submittedAt.day);
    final today = DateTime(now.year, now.month, now.day);
    return today.difference(start).inDays;
  }

  bool get hasCommissionExport => commissionDocIds.isNotEmpty;

  Map<String, dynamic> toFirestore({bool isCreate = false}) {
    return {
      'type': type.storageKey,
      'creditorId': creditorId,
      'creditorName': creditorName,
      if (isCreate) 'submittedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'formData': formData,
      'summaryRows': summaryRows.map((row) => row.toMap()).toList(),
      'commissionDocIds': commissionDocIds,
    };
  }

  factory BackofficePendingPlan.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
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
      id: doc.id,
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
  static CollectionReference<Map<String, dynamic>>? _collection() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('backoffice_pending_plans');
  }

  static Stream<List<BackofficePendingPlan>> watchAll() {
    final collection = _collection();
    if (collection == null) {
      return const Stream.empty();
    }
    return collection
        .orderBy('submittedAt', descending: true)
        .snapshots()
        .map(
          (snap) => snap.docs.map(BackofficePendingPlan.fromDoc).toList(),
        );
  }

  static Future<BackofficePendingSaveResult> save({
    String? existingId,
    required BackofficePendingPlanType type,
    required String creditorId,
    required String creditorName,
    required Map<String, dynamic> formData,
    required List<BackofficeSummaryRow> summaryRows,
    List<String> commissionDocIds = const [],
  }) async {
    final collection = _collection();
    if (collection == null) {
      return const BackofficePendingSaveResult(
        errorMessage: 'Devi essere autenticato per salvare il piano.',
      );
    }

    final docRef = existingId != null && existingId.isNotEmpty
        ? collection.doc(existingId)
        : collection.doc();

    final payload = {
      'type': type.storageKey,
      'creditorId': creditorId,
      'creditorName': creditorName,
      'updatedAt': FieldValue.serverTimestamp(),
      'formData': formData,
      'summaryRows': summaryRows.map((row) => row.toMap()).toList(),
      'commissionDocIds': commissionDocIds,
    };

    if (existingId == null || existingId.isEmpty) {
      payload['submittedAt'] = FieldValue.serverTimestamp();
    } else {
      payload['modifiedAt'] = FieldValue.serverTimestamp();
    }

    try {
      await docRef.set(payload, SetOptions(merge: true));
      return BackofficePendingSaveResult(id: docRef.id);
    } on FirebaseException catch (error) {
      return BackofficePendingSaveResult(
        errorMessage: _friendlyFirestoreError(error),
      );
    } catch (error) {
      return BackofficePendingSaveResult(
        errorMessage: 'Errore durante il salvataggio: $error',
      );
    }
  }

  static String _friendlyFirestoreError(FirebaseException error) {
    if (error.code == 'permission-denied') {
      return 'Permesso negato su Firestore. '
          'Le regole devono essere aggiornate sul progetto Firebase.';
    }
    return error.message ?? 'Errore Firestore (${error.code}).';
  }

  static Future<void> delete(String id) async {
    final collection = _collection();
    if (collection == null) return;
    await collection.doc(id).delete();
  }

  static Future<void> updateCommissionDocIds(
    String id,
    List<String> docIds,
  ) async {
    final collection = _collection();
    if (collection == null) return;
    await collection.doc(id).set(
      {
        'commissionDocIds': docIds,
        'updatedAt': FieldValue.serverTimestamp(),
        'acceptedAt': FieldValue.serverTimestamp(),
        'acceptedVia': BackofficeAcceptedVia.commission.storageKey,
      },
      SetOptions(merge: true),
    );
  }

  static Future<void> markAcceptedManual(String id) async {
    final collection = _collection();
    if (collection == null) return;
    await collection.doc(id).set(
      {
        'acceptedAt': FieldValue.serverTimestamp(),
        'acceptedVia': BackofficeAcceptedVia.manual.storageKey,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }
}
