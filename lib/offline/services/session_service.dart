import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/session_info.dart';

enum AppSessionRole { primary, secondaryBlocked }

/// Sessione unica app: un account attivo su un solo dispositivo CreditCalc.
class SessionService {
  SessionService({required this.userId});

  static const _staleAfter = Duration(minutes: 2);
  static const _deviceIdKey = 'credit_calc_device_id';
  static const _platform = 'calc_store';

  final String userId;
  final _roleController = StreamController<AppSessionRole>.broadcast();

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _watchSub;
  Timer? _heartbeat;
  AppSessionRole _role = AppSessionRole.primary;
  SessionInfo? _conflict;
  bool _initialized = false;

  AppSessionRole get role => _role;
  SessionInfo? get conflict => _conflict;
  Stream<AppSessionRole> get roleStream => _roleController.stream;

  DocumentReference<Map<String, dynamic>> get _ref =>
      FirebaseFirestore.instance.collection('credit_calc_sessions').doc(userId);

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    final claimed = await _claim();
    _applyRole(claimed);

    if (_role == AppSessionRole.primary) {
      _startHeartbeat();
    }

    _watchSub = _ref.snapshots().listen(
      (snap) => unawaited(_onRemoteSnapshot(snap)),
      onError: (_) {},
    );
  }

  Future<AppSessionRole> _claim() async {
    try {
      final localDeviceId = await _deviceId();
      final profile = await _deviceProfile();
      final sessionId = const Uuid().v4();

      final role = await FirebaseFirestore.instance.runTransaction(
        (tx) async {
          final snap = await tx.get(_ref);
          final remote = _readAppSession(snap.data());

          if (remote != null &&
              remote.active &&
              remote.deviceId.isNotEmpty &&
              remote.deviceId != localDeviceId &&
              !_isStale(remote.lastActivity)) {
            _conflict = remote;
            return AppSessionRole.secondaryBlocked;
          }

          tx.set(
            _ref,
            {
              'userId': userId,
              'appSession': {
                'sessionId': sessionId,
                'userId': userId,
                'deviceId': localDeviceId,
                'deviceType': profile.type,
                'deviceLabel': profile.label,
                'platform': _platform,
                'lastActivity': FieldValue.serverTimestamp(),
                'active': true,
              },
            },
            SetOptions(merge: true),
          );
          _conflict = null;
          return AppSessionRole.primary;
        },
      );

      return role;
    } on FirebaseException catch (e) {
      if (kDebugMode) {
        debugPrint('SessionService.claim: ${e.code} ${e.message}');
      }
      return AppSessionRole.primary;
    } catch (e) {
      if (kDebugMode) debugPrint('SessionService.claim: $e');
      return AppSessionRole.primary;
    }
  }

  Future<void> _onRemoteSnapshot(
    DocumentSnapshot<Map<String, dynamic>> snap,
  ) async {
    if (!_initialized) return;

    final localDeviceId = await _deviceId();
    final remote = _readAppSession(snap.data());

    final remoteFree = remote == null ||
        !remote.active ||
        remote.deviceId.isEmpty ||
        remote.deviceId == localDeviceId ||
        _isStale(remote.lastActivity);

    if (remoteFree) {
      if (_role == AppSessionRole.secondaryBlocked) {
        final claimed = await _claim();
        _applyRole(claimed);
        if (_role == AppSessionRole.primary) {
          _startHeartbeat();
        }
      }
      return;
    }

    _conflict = remote;
    if (_role != AppSessionRole.secondaryBlocked) {
      _heartbeat?.cancel();
      _applyRole(AppSessionRole.secondaryBlocked);
    }
  }

  void _applyRole(AppSessionRole role) {
    if (_role == role) return;
    _role = role;
    if (!_roleController.isClosed) {
      _roleController.add(role);
    }
  }

  void _startHeartbeat() {
    _heartbeat?.cancel();
    _heartbeat = Timer.periodic(const Duration(minutes: 1), (_) {
      unawaited(_touch());
    });
  }

  Future<void> retryClaim() async {
    final claimed = await _claim();
    _applyRole(claimed);
    if (_role == AppSessionRole.primary) {
      _startHeartbeat();
    } else {
      _heartbeat?.cancel();
    }
  }

  /// Rimuove la sessione app da Firestore (solo se questo dispositivo è il titolare).
  Future<void> releaseIfHolder() async {
    try {
      final localDeviceId = await _deviceId();
      final snap = await _ref.get(const GetOptions(source: Source.server));
      final remote = _readAppSession(snap.data());
      if (remote == null || remote.deviceId != localDeviceId) return;

      await _ref.update({'appSession': FieldValue.delete()});
    } on FirebaseException catch (e) {
      if (e.code == 'not-found') return;
      if (kDebugMode) {
        debugPrint('SessionService.releaseIfHolder: ${e.code} ${e.message}');
      }
      try {
        await _ref.set(
          {
            'userId': userId,
            'appSession': {'active': false},
          },
          SetOptions(merge: true),
        );
      } catch (_) {}
    } catch (e) {
      if (kDebugMode) debugPrint('SessionService.releaseIfHolder: $e');
    }
  }

  Future<void> _touch() async {
    if (_role != AppSessionRole.primary) return;

    try {
      final localDeviceId = await _deviceId();
      await _ref.set(
        {
          'userId': userId,
          'appSession': {
            'deviceId': localDeviceId,
            'lastActivity': FieldValue.serverTimestamp(),
            'active': true,
          },
        },
        SetOptions(merge: true),
      );
    } catch (_) {}
  }

  void dispose() {
    _heartbeat?.cancel();
    _watchSub?.cancel();
    if (!_roleController.isClosed) {
      _roleController.close();
    }
    _initialized = false;
  }

  SessionInfo? _readAppSession(Map<String, dynamic>? data) {
    if (data == null) return null;
    final raw = data['appSession'];
    if (raw is! Map) return null;
    return SessionInfo.fromFirestore(Map<String, dynamic>.from(raw));
  }

  static bool _isStale(DateTime? lastActivity) {
    if (lastActivity == null) return true;
    return DateTime.now().difference(lastActivity) > _staleAfter;
  }

  static Future<String> _deviceId() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_deviceIdKey);
    if (existing != null && existing.isNotEmpty) return existing;
    final id = const Uuid().v4();
    await prefs.setString(_deviceIdKey, id);
    return id;
  }

  static Future<({String type, String label})> _deviceProfile() async {
    if (kIsWeb) {
      return (type: 'web', label: 'Browser Web');
    }
    try {
      if (Platform.isAndroid || Platform.isIOS) {
        return (type: 'mobile', label: 'Telefono o tablet');
      }
      if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
        final name = Platform.localHostname;
        return (
          type: 'desktop',
          label: name.isNotEmpty ? name : 'Computer',
        );
      }
    } catch (_) {}
    return (type: 'unknown', label: 'Dispositivo');
  }
}
