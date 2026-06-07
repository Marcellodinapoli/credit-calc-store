import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'fcm_background_handler.dart';
import 'local_notifications_service.dart';
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
    if (notification == null) return;

    await LocalNotificationsService.showProductNotification(
      title: notification.title ?? 'CreditCore',
      body: notification.body ?? 'Nuovo aggiornamento disponibile',
    );
  }

  static void _onMessageOpenedApp(RemoteMessage message) {
    if (kDebugMode) {
      debugPrint(
        'FCM opened: ${message.notification?.title ?? message.data}',
      );
    }
  }
}
