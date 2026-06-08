import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/sync_record_status.dart';
import 'local_database_service.dart';

/// Bozze locali dei piani di rientro (offline).
abstract final class RepaymentPlanDraftService {
  static const typeStandard = 'standard_repayment';
  static const typeBalanceWriteOff = 'balance_write_off';

  static String _draftId(String userId, String planType) =>
      '${userId}_$planType';

  static Future<void> saveDraft({
    required String userId,
    required String planType,
    required Map<String, dynamic> state,
  }) async {
    final now = DateTime.now();
    await LocalDatabaseService.instance.upsertRecord(
      collection: 'plan_drafts',
      id: _draftId(userId, planType),
      userId: userId,
      payload: {
        'planType': planType,
        'state': state,
        'updatedAt': Timestamp.fromDate(now),
      },
      createdAt: now,
      updatedAt: now,
      syncStatus: SyncRecordStatus.synced,
      origin: 'local',
    );
  }

  static Future<Map<String, dynamic>?> loadDraft({
    required String userId,
    required String planType,
  }) async {
    final row = await LocalDatabaseService.instance.recordById(
      collection: 'plan_drafts',
      id: _draftId(userId, planType),
    );
    if (row == null) return null;
    final payload = row['payload'] as Map<String, dynamic>;
    final state = payload['state'];
    if (state is Map<String, dynamic>) return state;
    if (state is Map) return Map<String, dynamic>.from(state);
    if (state is String) {
      return jsonDecode(state) as Map<String, dynamic>;
    }
    return null;
  }

  static Future<void> clearDraft({
    required String userId,
    required String planType,
  }) async {
    final row = await LocalDatabaseService.instance.recordById(
      collection: 'plan_drafts',
      id: _draftId(userId, planType),
    );
    if (row == null) return;
    final payload = Map<String, dynamic>.from(row['payload'] as Map);
    payload['_deleted'] = true;
    await LocalDatabaseService.instance.upsertRecord(
      collection: 'plan_drafts',
      id: _draftId(userId, planType),
      userId: userId,
      payload: payload,
      createdAt: row['createdAt'] as DateTime,
      updatedAt: DateTime.now(),
      syncStatus: SyncRecordStatus.synced,
      origin: 'local',
    );
  }
}
