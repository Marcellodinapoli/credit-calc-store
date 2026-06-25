import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'section_lock_config.dart';
import 'section_lock_device.dart';

enum SectionLockAcquireResult { acquired, blocked, unauthenticated }

class SectionLockState {
  const SectionLockState({
    required this.sectionKey,
    required this.lockedBy,
    required this.deviceId,
    required this.lockedAt,
    required this.ownedByThisDevice,
  });

  final String sectionKey;
  final String lockedBy;
  final String deviceId;
  final DateTime lockedAt;
  final bool ownedByThisDevice;

  bool get isBlocked => !ownedByThisDevice;
}

/// Blocco record per sezione: più dispositivi, una sola modifica alla volta.
abstract final class SectionLockService {
  static const staleAfter = Duration(minutes: 3);

  static final _firestore = FirebaseFirestore.instance;
  static final _locks = _firestore.collection('section_locks');

  static String? get _userId => FirebaseAuth.instance.currentUser?.uid;

  static String _docId(String userId, String sectionKey) =>
      '${userId}__${sectionKey.replaceAll('/', '_')}';

  static DateTime? _readTimestamp(dynamic raw) {
    if (raw is Timestamp) return raw.toDate();
    return null;
  }

  static bool _isStale(DateTime? lockedAt, DateTime? lastActivity) {
    final anchor = lastActivity ?? lockedAt;
    if (anchor == null) return true;
    return DateTime.now().difference(anchor) > staleAfter;
  }

  static SectionLockState? _fromDoc(
    String sectionKey,
    String localDeviceId,
    DocumentSnapshot<Map<String, dynamic>> snap,
  ) {
    if (!snap.exists) return null;
    final data = snap.data() ?? {};
    final deviceId = (data['deviceId'] ?? '').toString();
    final lockedAt = _readTimestamp(data['lockedAt']) ?? DateTime.now();
    return SectionLockState(
      sectionKey: sectionKey,
      lockedBy: (data['lockedBy'] ?? '').toString(),
      deviceId: deviceId,
      lockedAt: lockedAt,
      ownedByThisDevice: deviceId == localDeviceId,
    );
  }

  static Future<SectionLockAcquireResult> acquire(String sectionKey) async {
    final userId = _userId;
    if (userId == null) return SectionLockAcquireResult.unauthenticated;

    final localDeviceId = await SectionLockDevice.deviceId();
    final ref = _locks.doc(_docId(userId, sectionKey));

    return _firestore.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final now = FieldValue.serverTimestamp();

      if (!snap.exists) {
        tx.set(ref, {
          'lockedBy': userId,
          'sectionKey': sectionKey,
          'deviceId': localDeviceId,
          'platform': SectionLockConfig.platformChannel,
          'lockedAt': now,
          'lastActivity': now,
        });
        return SectionLockAcquireResult.acquired;
      }

      final data = snap.data() ?? {};
      final holderDevice = (data['deviceId'] ?? '').toString();
      final lockedAt = _readTimestamp(data['lockedAt']);
      final lastActivity = _readTimestamp(data['lastActivity']);

      if (holderDevice == localDeviceId || _isStale(lockedAt, lastActivity)) {
        tx.set(
          ref,
          {
            'lockedBy': userId,
            'sectionKey': sectionKey,
            'deviceId': localDeviceId,
            'platform': SectionLockConfig.platformChannel,
            'lockedAt': now,
            'lastActivity': now,
          },
          SetOptions(merge: true),
        );
        return SectionLockAcquireResult.acquired;
      }

      return SectionLockAcquireResult.blocked;
    });
  }

  static Future<void> touch(String sectionKey) async {
    final userId = _userId;
    if (userId == null) return;

    final localDeviceId = await SectionLockDevice.deviceId();
    final ref = _locks.doc(_docId(userId, sectionKey));
    final snap = await ref.get();
    if (!snap.exists) return;

    final data = snap.data() ?? {};
    if ((data['deviceId'] ?? '').toString() != localDeviceId) return;

    await ref.set(
      {'lastActivity': FieldValue.serverTimestamp()},
      SetOptions(merge: true),
    );
  }

  static Future<void> release(String sectionKey) async {
    final userId = _userId;
    if (userId == null) return;

    final localDeviceId = await SectionLockDevice.deviceId();
    final ref = _locks.doc(_docId(userId, sectionKey));

    await _firestore.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) return;
      final data = snap.data() ?? {};
      if ((data['deviceId'] ?? '').toString() == localDeviceId) {
        tx.delete(ref);
      }
    });
  }

  static Stream<SectionLockState?> watch(String sectionKey) async* {
    final userId = _userId;
    if (userId == null) {
      yield null;
      return;
    }

    final localDeviceId = await SectionLockDevice.deviceId();
    final ref = _locks.doc(_docId(userId, sectionKey));

    yield* ref.snapshots().map(
          (snap) => _fromDoc(sectionKey, localDeviceId, snap),
        );
  }
}
