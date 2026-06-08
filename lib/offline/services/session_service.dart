import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../models/session_info.dart';
import 'connectivity_service.dart';
import 'device_identity_service.dart';

/// Sessione unica CreditCalc (un dispositivo attivo per utente).
class SessionService {
  SessionService({required this.userId});

  final String userId;
  final _sessions = FirebaseFirestore.instance.collection('credit_calc_sessions');

  DocumentReference<Map<String, dynamic>> get _doc => _sessions.doc(userId);

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _watchSub;
  String? _activeSessionId;
  String? _localDeviceId;
  void Function()? _onSessionRevoked;

  Future<SessionInfo?> currentSession() async {
    try {
      final snap = await _doc.get().timeout(const Duration(seconds: 4));
      if (!snap.exists || snap.data() == null) return null;
      return SessionInfo.fromFirestore(snap.data()!);
    } catch (_) {
      return null;
    }
  }

  /// `null` = ok; altrimenti sessione di un altro dispositivo attiva.
  Future<SessionInfo?> findConflictingSession() async {
    final localDeviceId = await DeviceIdentityService.deviceId();
    _localDeviceId = localDeviceId;
    final remote = await currentSession();
    if (remote == null || !remote.active) return null;
    if (remote.deviceId == localDeviceId) return null;
    return remote;
  }

  Future<void> claimSession({bool refreshSessionId = false}) async {
    final deviceId = await DeviceIdentityService.deviceId();
    final profile = await DeviceIdentityService.deviceProfile();
    _localDeviceId = deviceId;
    _activeSessionId =
        refreshSessionId ? const Uuid().v4() : (_activeSessionId ?? const Uuid().v4());

    try {
      await _doc.set(
        SessionInfo(
          sessionId: _activeSessionId!,
          userId: userId,
          deviceId: deviceId,
          deviceType: profile.type,
          deviceLabel: profile.label,
          lastActivity: DateTime.now(),
          active: true,
        ).toFirestore(),
        SetOptions(merge: true),
      );
    } catch (_) {
      // Offline: sessione locale; claim remoto al ritorno della rete.
    }
  }

  Future<void> touchActivity() async {
    if (_activeSessionId == null) return;
    try {
      await _doc.set(
        {
          'lastActivity': FieldValue.serverTimestamp(),
          'active': true,
        },
        SetOptions(merge: true),
      );
    } catch (_) {}
  }

  Future<void> releaseSession() async {
    stopWatching();
    _activeSessionId = null;

    if (!await ConnectivityService.isOnline()) return;

    try {
      final deviceId = _localDeviceId ?? await DeviceIdentityService.deviceId();
      final remote = await currentSession().timeout(
        const Duration(seconds: 4),
        onTimeout: () => null,
      );
      if (remote?.deviceId == deviceId) {
        await _doc
            .set({'active': false}, SetOptions(merge: true))
            .timeout(const Duration(seconds: 4));
      }
    } catch (_) {
      // Uscita locale: la sessione remota scadrà o verrà riconquistata online.
    }
  }

  /// `true` se questo dispositivo ha reclamato la sessione e può lavorare.
  Future<bool> holdsActiveSession() async {
    if (_activeSessionId == null) return false;
    try {
      final localDeviceId =
          _localDeviceId ?? await DeviceIdentityService.deviceId();
      final remote = await currentSession();
      if (remote == null || !remote.active) return true;
      return remote.deviceId == localDeviceId;
    } catch (_) {
      // Rete lenta o assente: non bloccare lettura/sync locale già reclamata.
      return true;
    }
  }

  Future<void> ensureLocalSession() async {
    if (_activeSessionId == null) {
      await claimSession();
    }
  }

  /// Verifica che la sessione locale sia ancora valida (sync e realtime).
  Future<bool> isLocalSessionValid() => holdsActiveSession();

  void startWatching({required VoidCallback onSessionRevoked}) {
    _onSessionRevoked = onSessionRevoked;
    _watchSub?.cancel();
    _watchSub = _doc.snapshots().listen((snap) async {
      if (!snap.exists || snap.data() == null) return;
      final info = SessionInfo.fromFirestore(snap.data()!);
      final localDeviceId = _localDeviceId ?? await DeviceIdentityService.deviceId();
      if (!info.active) return;
      if (info.deviceId != localDeviceId) {
        _onSessionRevoked?.call();
      } else {
        _activeSessionId = info.sessionId;
      }
    });
  }

  void stopWatching() {
    _watchSub?.cancel();
    _watchSub = null;
    _onSessionRevoked = null;
  }

  Future<void> forceLogoutIfInvalid() async {
    final valid = await isLocalSessionValid();
    if (valid) return;
    stopWatching();
    await FirebaseAuth.instance.signOut();
  }

  void dispose() => stopWatching();
}
