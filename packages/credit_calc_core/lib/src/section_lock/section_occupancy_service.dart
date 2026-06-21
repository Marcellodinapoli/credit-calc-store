import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../core/firestore_server_reads.dart';
import 'device_identity.dart';
import 'section_lock_config.dart';
import 'section_occupancy_result.dart';

/// Occupazione per sezione: un solo dispositivo per sezione, senza bloccare l'app.
abstract final class SectionOccupancyService {
  static const _staleAfter = Duration(minutes: 10);

  static CollectionReference<Map<String, dynamic>> get _sessions =>
      FirebaseFirestore.instance.collection('credit_calc_sessions');

  static Future<String?> _userId() async {
    return FirebaseAuth.instance.currentUser?.uid;
  }

  static Map<String, dynamic>? _readSection(
    Map<String, dynamic>? data,
    String sectionKey,
  ) {
    final sections = data?['sections'];
    if (sections is! Map) return null;
    final raw = sections[sectionKey];
    if (raw is! Map) return null;
    return Map<String, dynamic>.from(raw);
  }

  static bool _isActive(Map<String, dynamic> section) {
    if (section['active'] != true) return false;
    final last = section['lastActivity'];
    if (last is! Timestamp) return true;
    return DateTime.now().difference(last.toDate()) <= _staleAfter;
  }

  static SectionOccupancyResult _resultFromRemoteSection({
    required String sectionKey,
    required Map<String, dynamic> section,
    required String localDeviceId,
  }) {
    if (!_isActive(section)) return SectionOccupancyResult.allowedFree;

    final remoteDeviceId = (section['deviceId'] ?? '').toString();
    if (remoteDeviceId.isEmpty || remoteDeviceId == localDeviceId) {
      return SectionOccupancyResult.allowedFree;
    }

    final label = (section['deviceLabel'] ?? 'Altro dispositivo').toString();
    final type = (section['deviceType'] ?? '').toString();
    final title = SectionLockConfig.titleFor(sectionKey) ?? 'Questa sezione';

    return SectionOccupancyResult(
      allowed: false,
      deviceLabel: label,
      deviceType: type,
      message:
          '$title è in uso su $label${type.isNotEmpty ? ' ($type)' : ''}.\n\n'
          'Puoi continuare a usare il resto dell\'app. '
          'Riprova quando l\'altra sessione ha chiuso questa sezione.',
    );
  }

  static SectionOccupancyResult _failOpenOnPermission(FirebaseException e) {
    if (e.code == 'permission-denied') {
      if (kDebugMode) {
        debugPrint(
          'SectionOccupancy: permessi Firestore mancanti, sezione sbloccata.',
        );
      }
      return SectionOccupancyResult.allowedFree;
    }
    if (kDebugMode) debugPrint('SectionOccupancy: $e');
    return SectionOccupancyResult.allowedFree;
  }

  static Future<SectionOccupancyResult> check(String sectionKey) async {
    if (!SectionLockConfig.isSupported(sectionKey)) {
      return SectionOccupancyResult.allowedFree;
    }

    final userId = await _userId();
    if (userId == null) return SectionOccupancyResult.allowedFree;

    final localDeviceId = await SectionDeviceIdentity.deviceId();

    try {
      final snap = await FirestoreServerReads.get(_sessions.doc(userId));
      if (!snap.exists) return SectionOccupancyResult.allowedFree;

      final section = _readSection(snap.data(), sectionKey);
      if (section == null) return SectionOccupancyResult.allowedFree;

      return _resultFromRemoteSection(
        sectionKey: sectionKey,
        section: section,
        localDeviceId: localDeviceId,
      );
    } on FirebaseException catch (e) {
      return _failOpenOnPermission(e);
    } catch (e) {
      if (kDebugMode) debugPrint('SectionOccupancy.check: $e');
      return SectionOccupancyResult.allowedFree;
    }
  }

  /// Verifica occupazione e registra questo dispositivo sulla sezione.
  static Future<SectionOccupancyResult> tryAcquire(String sectionKey) async {
    if (!SectionLockConfig.isSupported(sectionKey)) {
      return SectionOccupancyResult.allowedFree;
    }

    final userId = await _userId();
    if (userId == null) return SectionOccupancyResult.allowedFree;

    final localDeviceId = await SectionDeviceIdentity.deviceId();
    final profile = await SectionDeviceIdentity.deviceProfile();

    try {
      final blocked = await check(sectionKey);
      if (!blocked.allowed) return blocked;

      await _sessions.doc(userId).set(
        {
          'userId': userId,
          'sections': {
            sectionKey: {
              'deviceId': localDeviceId,
              'deviceLabel': profile.label,
              'deviceType': profile.type,
              'lastActivity': FieldValue.serverTimestamp(),
              'active': true,
            },
          },
        },
        SetOptions(merge: true),
      );

      return SectionOccupancyResult.allowedFree;
    } on FirebaseException catch (e) {
      return _failOpenOnPermission(e);
    } catch (e) {
      if (kDebugMode) debugPrint('SectionOccupancy.tryAcquire: $e');
      return SectionOccupancyResult.allowedFree;
    }
  }

  static Stream<SectionOccupancyResult> watch(String sectionKey) {
    if (!SectionLockConfig.isSupported(sectionKey)) {
      return Stream.value(SectionOccupancyResult.allowedFree);
    }
    return _watchStream(sectionKey);
  }

  static Stream<SectionOccupancyResult> _watchStream(String sectionKey) async* {
    final userId = await _userId();
    if (userId == null) {
      yield SectionOccupancyResult.allowedFree;
      return;
    }

    final localDeviceId = await SectionDeviceIdentity.deviceId();

    await for (final snap in FirestoreServerReads.watch(_sessions.doc(userId))) {
      if (!snap.exists) {
        yield SectionOccupancyResult.allowedFree;
        continue;
      }
      final section = _readSection(snap.data(), sectionKey);
      if (section == null) {
        yield SectionOccupancyResult.allowedFree;
        continue;
      }
      yield _resultFromRemoteSection(
        sectionKey: sectionKey,
        section: section,
        localDeviceId: localDeviceId,
      );
    }
  }

  static Future<void> claim(String sectionKey) async {
    await tryAcquire(sectionKey);
  }

  static Future<void> touch(String sectionKey) async {
    if (!SectionLockConfig.isSupported(sectionKey)) return;

    final userId = await _userId();
    if (userId == null) return;

    final localDeviceId = await SectionDeviceIdentity.deviceId();

    try {
      await _sessions.doc(userId).set(
        {
          'userId': userId,
          'sections': {
            sectionKey: {
              'deviceId': localDeviceId,
              'lastActivity': FieldValue.serverTimestamp(),
              'active': true,
            },
          },
        },
        SetOptions(merge: true),
      );
    } on FirebaseException catch (e) {
      _failOpenOnPermission(e);
    } catch (e) {
      if (kDebugMode) debugPrint('SectionOccupancy.touch: $e');
    }
  }

  static Future<void> release(String sectionKey) async {
    if (!SectionLockConfig.isSupported(sectionKey)) return;

    final userId = await _userId();
    if (userId == null) return;

    final localDeviceId = await SectionDeviceIdentity.deviceId();

    try {
      final snap = await FirestoreServerReads.get(_sessions.doc(userId));
      final section = _readSection(snap.data(), sectionKey);
      if (section == null) return;
      if ((section['deviceId'] ?? '').toString() != localDeviceId) return;

      await _sessions.doc(userId).set(
        {
          'userId': userId,
          'sections': {
            sectionKey: {'active': false},
          },
        },
        SetOptions(merge: true),
      );
    } on FirebaseException catch (e) {
      _failOpenOnPermission(e);
    } catch (e) {
      if (kDebugMode) debugPrint('SectionOccupancy.release: $e');
    }
  }
}
