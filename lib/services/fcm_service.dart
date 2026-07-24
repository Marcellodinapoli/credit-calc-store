import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'fcm_background_handler.dart';
import 'local_notifications_service.dart';
import 'notification_navigation.dart';
import 'product_notifications_service.dart';
import 'push_platform.dart';

/// Inizializzazione push FCM e sincronizzazione token con Firestore.
class FcmService {
  FcmService._();

  static final _messaging = FirebaseMessaging.instance;
  static bool _initialized = false;

  static Future<void> initialize() async {
    if (_initialized || kIsWeb) return;
    _initialized = true;

    await LocalNotificationsService.initialize();

    if (!supportsNativeFcmPush) return;

    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // Nessun dialog permessi all'avvio: l'utente attiva da Aggiornamenti.
    await _messaging.setAutoInitEnabled(false);

    if (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      await _messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
    }

    FirebaseMessaging.onMessage.listen(_onForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_onMessageOpenedApp);

    _messaging.onTokenRefresh.listen((token) async {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      await ProductNotificationsService.syncToken(uid: uid, token: token);
    });

    final initial = await _messaging.getInitialMessage();
    if (initial != null) {
      _onMessageOpenedApp(initial);
    }
  }

  /// Dopo login: aggiorna token solo se già attive e permesso già concesso.
  static Future<void> syncForCurrentUser() async {
    if (kIsWeb) return;

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    await ProductNotificationsService.refreshTokenIfEnabled(uid);
  }

  static Future<void> _onForegroundMessage(RemoteMessage message) async {
    if (kDebugMode) {
      debugPrint(
        'FCM foreground: ${message.notification?.title ?? message.data}',
      );
    }

    final notification = message.notification;
    final data = message.data;
    final type = data['type']?.toString() ?? '';
    final title =
        notification?.title ?? data['title']?.toString() ?? 'CreditCore';
    final body = notification?.body ??
        data['body']?.toString() ??
        'Nuovo aggiornamento disponibile';

    final localPayload = _localPayloadForData(data);
    if (type == 'field_visit' || type == 'field_reminder') {
      await LocalNotificationsService.showItineraryNotification(
        title: title,
        body: body,
        payload: localPayload,
      );
      return;
    }

    await LocalNotificationsService.showProductNotification(
      title: title,
      body: body,
      payload: localPayload,
    );
  }

  static String? _localPayloadForData(Map<String, dynamic> data) {
    final type = data['type']?.toString().trim() ?? '';
    if (type.isEmpty) return null;
    final id = data['announcementId'] ??
        data['offerId'] ??
        data['courseId'] ??
        data['visitId'] ??
        data['reminderId'] ??
        data['id'];
    final idStr = id?.toString().trim() ?? '';
    if (idStr.isEmpty) return NotificationNavigation.encodeLocalPayload(type, '');
    return NotificationNavigation.encodeLocalPayload(type, idStr);
  }

  static void _onMessageOpenedApp(RemoteMessage message) {
    if (kDebugMode) {
      debugPrint(
        'FCM opened: ${message.notification?.title ?? message.data}',
      );
    }
    NotificationNavigation.openFromRemoteMessage(message);
  }
}
