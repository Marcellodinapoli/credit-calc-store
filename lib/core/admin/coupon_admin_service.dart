import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../auth/registration_coupon_service.dart';

class CouponRecord {
  final String code;
  final bool enabled;
  final bool lifetimeFree;
  final int usedCount;
  final int? maxUses;
  final DateTime? expiresAt;
  final String? plan;
  final String? label;
  final DateTime? createdAt;
  final String? lastUsedBy;

  const CouponRecord({
    required this.code,
    required this.enabled,
    required this.lifetimeFree,
    required this.usedCount,
    this.maxUses,
    this.expiresAt,
    this.plan,
    this.label,
    this.createdAt,
    this.lastUsedBy,
  });

  factory CouponRecord.fromDoc(String id, Map<String, dynamic> data) {
    final expires = data['expiresAt'];
    final created = data['createdAt'];
    final maxUsesRaw = data['maxUses'];
    final usedRaw = data['usedCount'];

    return CouponRecord(
      code: id,
      enabled: data['enabled'] == true,
      lifetimeFree: data['lifetimeFree'] as bool? ?? true,
      usedCount: usedRaw is int
          ? usedRaw
          : usedRaw is num
              ? usedRaw.toInt()
              : 0,
      maxUses: maxUsesRaw is int
          ? maxUsesRaw
          : maxUsesRaw is num
              ? maxUsesRaw.toInt()
              : null,
      expiresAt: expires is Timestamp ? expires.toDate() : null,
      plan: (data['plan'] ?? '').toString().trim().isEmpty
          ? null
          : (data['plan'] ?? '').toString(),
      label: (data['label'] ?? '').toString().trim().isEmpty
          ? null
          : (data['label'] ?? '').toString(),
      createdAt: created is Timestamp ? created.toDate() : null,
      lastUsedBy: (data['lastUsedBy'] ?? '').toString().trim().isEmpty
          ? null
          : (data['lastUsedBy'] ?? '').toString(),
    );
  }

  bool get exhausted =>
      maxUses != null && maxUses! > 0 && usedCount >= maxUses!;

  bool get expired =>
      expiresAt != null && expiresAt!.isBefore(DateTime.now());
}

abstract final class CouponAdminService {
  static final _col = FirebaseFirestore.instance.collection('coupons');

  static Stream<List<CouponRecord>> watchCoupons() {
    return _col.snapshots().map((snap) {
      final list = snap.docs
          .map((d) => CouponRecord.fromDoc(d.id, d.data()))
          .toList();
      list.sort((a, b) {
        final ac = a.createdAt?.millisecondsSinceEpoch ?? 0;
        final bc = b.createdAt?.millisecondsSinceEpoch ?? 0;
        return bc.compareTo(ac);
      });
      return list;
    });
  }

  static Future<void> createCoupon({
    required String code,
    String? label,
    int? maxUses,
    DateTime? expiresAt,
    String? restrictedPlan,
  }) async {
    final normalized = RegistrationCouponService.normalizeCode(code);
    if (normalized.isEmpty) {
      throw ArgumentError('Codice coupon obbligatorio');
    }

    final existing = await _col.doc(normalized).get();
    if (existing.exists) {
      throw StateError('Esiste già un coupon con questo codice.');
    }

    final uid = FirebaseAuth.instance.currentUser?.uid;
    await _col.doc(normalized).set({
      'enabled': true,
      'lifetimeFree': true,
      'usedCount': 0,
      if (label != null && label.trim().isNotEmpty) 'label': label.trim(),
      if (maxUses != null && maxUses > 0) 'maxUses': maxUses,
      if (expiresAt != null) 'expiresAt': Timestamp.fromDate(expiresAt),
      if (restrictedPlan != null && restrictedPlan.trim().isNotEmpty)
        'plan': restrictedPlan.trim().toLowerCase(),
      'createdAt': FieldValue.serverTimestamp(),
      if (uid != null) 'createdBy': uid,
    });
  }

  static Future<void> setEnabled({
    required String code,
    required bool enabled,
  }) async {
    final normalized = RegistrationCouponService.normalizeCode(code);
    await _col.doc(normalized).set(
      {'enabled': enabled},
      SetOptions(merge: true),
    );
  }
}
