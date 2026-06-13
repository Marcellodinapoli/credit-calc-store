import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'desktop_push_service.dart';
import 'local_notifications_service.dart';
import 'push_platform.dart';

/// Preferenze notifiche di prodotto (offerte, corsi, funzioni — non marketing).
class ProductNotificationsService {
  ProductNotificationsService._();

  static const String fieldEnabled = 'productNotificationsEnabled';
  static const String fieldUpdatedAt = 'productNotificationsUpdatedAt';
  static const String fieldToken = 'fcmToken';
  static const String fieldPushPlatform = 'pushPlatform';

  static final _firestore = FirebaseFirestore.instance;
  static final _messaging = FirebaseMessaging.instance;

  static Future<bool> loadEnabled(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    return doc.data()?[fieldEnabled] == true;
  }

  /// Attiva/disattiva le notifiche. Chiede il permesso solo con [enabled] true
  /// (es. toggle manuale in Area personale → Aggiornamenti).
  static Future<ProductNotificationsResult> setEnabled({
    required String uid,
    required bool enabled,
    bool requestPermission = true,
  }) async {
    final ref = _firestore.collection('users').doc(uid);
    final data = <String, dynamic>{
      fieldEnabled: enabled,
      fieldUpdatedAt: FieldValue.serverTimestamp(),
    };

    if (!enabled) {
      data[fieldToken] = FieldValue.delete();
      data[fieldPushPlatform] = FieldValue.delete();
      await ref.set(data, SetOptions(merge: true));
      await DesktopPushService.stop();
      return const ProductNotificationsResult(success: true);
    }

    if (supportsDesktopLocalPush) {
      return _setEnabledDesktop(
        uid: uid,
        ref: ref,
        data: data,
        requestPermission: requestPermission,
      );
    }

    final tokenResult = requestPermission
        ? await _requestPermissionAndToken()
        : await _readTokenIfPermitted();

    if (requestPermission &&
        enabled &&
        tokenResult.permissionIssue != null &&
        (tokenResult.token == null || tokenResult.token!.isEmpty)) {
      await ref.set(data, SetOptions(merge: true));
      return ProductNotificationsResult(
        success: true,
        permissionIssue: tokenResult.permissionIssue,
        tokenRegistered: false,
      );
    }

    if (tokenResult.token != null && tokenResult.token!.isNotEmpty) {
      data[fieldToken] = tokenResult.token;
      data[fieldPushPlatform] = pushPlatformLabel;
    }

    await ref.set(data, SetOptions(merge: true));

    return ProductNotificationsResult(
      success: true,
      permissionIssue: tokenResult.permissionIssue,
      tokenRegistered: tokenResult.token != null && tokenResult.token!.isNotEmpty,
    );
  }

  static Future<ProductNotificationsResult> _setEnabledDesktop({
    required String uid,
    required DocumentReference<Map<String, dynamic>> ref,
    required Map<String, dynamic> data,
    required bool requestPermission,
  }) async {
    if (requestPermission) {
      final granted = await LocalNotificationsService.requestPermission();
      if (!granted) {
        await ref.set(data, SetOptions(merge: true));
        return const ProductNotificationsResult(
          success: true,
          permissionIssue:
              'Permesso notifiche non concesso. Puoi attivarlo dalle impostazioni di Windows.',
          tokenRegistered: false,
        );
      }
    }

    data[fieldPushPlatform] = 'windows';
    data[fieldToken] = FieldValue.delete();
    await ref.set(data, SetOptions(merge: true));
    await DesktopPushService.start(uid);

    return const ProductNotificationsResult(
      success: true,
      tokenRegistered: true,
    );
  }

  /// Aggiorna il token senza mostrare dialog permessi (login / refresh FCM).
  static Future<void> refreshTokenIfEnabled(String uid) async {
    if (!await loadEnabled(uid)) return;

    if (supportsDesktopLocalPush) {
      await DesktopPushService.syncForCurrentUser(uid);
      return;
    }

    if (!supportsNativeFcmPush) return;
    if (!await _hasFcmPermission()) return;

    try {
      final token = await _messaging.getToken();
      if (token == null || token.isEmpty) return;
      await syncToken(uid: uid, token: token);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('FCM refresh token: $e');
      }
    }
  }

  /// Aggiorna solo il token (es. refresh FCM) se le notifiche sono attive.
  static Future<void> syncToken({
    required String uid,
    required String token,
  }) async {
    if (token.isEmpty) return;

    final enabled = await loadEnabled(uid);
    if (!enabled) return;

    await _firestore.collection('users').doc(uid).set(
      {
        fieldToken: token,
        fieldPushPlatform: pushPlatformLabel,
        fieldUpdatedAt: FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  static Future<bool> hasSystemPermission() async {
    if (!supportsNativeFcmPush) return false;
    return _hasFcmPermission();
  }

  static Future<bool> _hasFcmPermission() async {
    final settings = await _messaging.getNotificationSettings();
    return settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
  }

  static Future<_TokenRequestResult> _requestPermissionAndToken() async {
    if (!supportsNativeFcmPush) {
      return const _TokenRequestResult(
        permissionIssue: 'Push non disponibile su questa piattaforma.',
      );
    }

    try {
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      final allowed = settings.authorizationStatus ==
              AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;

      if (!allowed) {
        return const _TokenRequestResult(
          permissionIssue:
              'Permesso notifiche non concesso. Puoi attivarlo dalle impostazioni del dispositivo.',
        );
      }

      await _messaging.setAutoInitEnabled(true);
      final token = await _messaging.getToken();
      return _TokenRequestResult(token: token);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('FCM token: $e');
      }
      return const _TokenRequestResult(
        permissionIssue:
            'Impossibile registrare il dispositivo per le notifiche push.',
      );
    }
  }

  static Future<_TokenRequestResult> _readTokenIfPermitted() async {
    if (!supportsNativeFcmPush) {
      return const _TokenRequestResult();
    }

    if (!await _hasFcmPermission()) {
      return const _TokenRequestResult();
    }

    try {
      final token = await _messaging.getToken();
      return _TokenRequestResult(token: token);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('FCM read token: $e');
      }
      return const _TokenRequestResult();
    }
  }
}

class _TokenRequestResult {
  const _TokenRequestResult({this.token, this.permissionIssue});

  final String? token;
  final String? permissionIssue;
}

class ProductNotificationsResult {
  const ProductNotificationsResult({
    required this.success,
    this.permissionIssue,
    this.tokenRegistered = false,
  });

  final bool success;
  final String? permissionIssue;
  final bool tokenRegistered;
}
