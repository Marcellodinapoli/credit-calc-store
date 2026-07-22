import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Notifiche di sistema per foreground FCM, promemoria itinerario e push desktop.
class LocalNotificationsService {
  LocalNotificationsService._();

  static const _channelId = 'creditcore_product';
  static const _channelName = 'Aggiornamenti CreditCore';
  static const _itineraryChannelId = 'creditcore_itinerary';
  static const _itineraryChannelName = 'Itinerario CreditCalc';
  static const _clearBadgeNotificationId = 91001;

  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;
  static bool _timeZonesReady = false;

  static Future<void> initialize() async {
    if (_initialized || kIsWeb) return;
    _initialized = true;

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
      macOS: iosSettings,
      windows: WindowsInitializationSettings(
        appName: 'CreditCalc',
        appUserModelId: 'com.creditcore.creditcalc',
        guid: '7E8F9A0B-1C2D-4E5F-9A8B-7C6D5E4F3A2B',
      ),
    );

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (_) {
        clearAppIconBadge();
      },
    );
    await _ensureTimeZones();

    final launch = await _plugin.getNotificationAppLaunchDetails();
    if (launch?.didNotificationLaunchApp == true) {
      await clearAppIconBadge();
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await android?.createNotificationChannel(
        const AndroidNotificationChannel(
          _channelId,
          _channelName,
          description: 'Novità su offerte, corsi e funzioni CreditCore',
          importance: Importance.high,
        ),
      );
      await android?.createNotificationChannel(
        const AndroidNotificationChannel(
          _itineraryChannelId,
          _itineraryChannelName,
          description: 'Promemoria itinerario e avvisi pre-visita',
          importance: Importance.high,
          showBadge: true,
        ),
      );
    }
  }

  static Future<void> _ensureTimeZones() async {
    if (_timeZonesReady) return;
    tz_data.initializeTimeZones();
    try {
      final timeZoneName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timeZoneName));
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('Europe/Rome'));
    }
    _timeZonesReady = true;
  }

  static Future<bool> requestPermission() async {
    if (kIsWeb) return false;

    if (defaultTargetPlatform == TargetPlatform.windows) {
      return true;
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (android == null) return false;

      final enabled = await android.areNotificationsEnabled();
      if (enabled == true) return true;

      final granted = await android.requestNotificationsPermission();
      return granted ?? false;
    }

    if (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      final ios = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      final macos = _plugin.resolvePlatformSpecificImplementation<
          MacOSFlutterLocalNotificationsPlugin>();
      if (ios != null) {
        final granted = await ios.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
        return granted ?? false;
      }
      if (macos != null) {
        final granted = await macos.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
        return granted ?? false;
      }
      return false;
    }

    return true;
  }

  /// Verifica se il permesso notifiche è già concesso (senza chiedere nulla).
  static Future<bool> hasPermission() async {
    if (!_initialized || kIsWeb) return false;

    if (defaultTargetPlatform == TargetPlatform.android) {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      return await android?.areNotificationsEnabled() ?? false;
    }

    if (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      return true;
    }

    return true;
  }

  /// Chiede il permesso solo se [allowPrompt] è true e non è già concesso.
  static Future<bool> ensurePermission({bool allowPrompt = true}) async {
    if (await hasPermission()) return true;
    if (!allowPrompt) return false;
    return requestPermission();
  }

  /// Toglie il pallino/numero sull'icona (iOS/macOS; su Android sparisce con la notifica).
  static Future<void> clearAppIconBadge() async {
    if (kIsWeb || !_initialized) return;
    if (defaultTargetPlatform != TargetPlatform.iOS &&
        defaultTargetPlatform != TargetPlatform.macOS) {
      return;
    }
    try {
      await _plugin.show(
        _clearBadgeNotificationId,
        null,
        null,
        const NotificationDetails(
          iOS: DarwinNotificationDetails(
            presentAlert: false,
            presentBadge: true,
            presentSound: false,
            badgeNumber: 0,
          ),
          macOS: DarwinNotificationDetails(
            presentAlert: false,
            presentBadge: true,
            presentSound: false,
            badgeNumber: 0,
          ),
        ),
      );
      await _plugin.cancel(_clearBadgeNotificationId);
    } catch (_) {}
  }

  static Future<void> showProductNotification({
    required String title,
    required String body,
    String? payload,
  }) {
    return _showNotification(
      title: title,
      body: body,
      payload: payload,
      channelId: _channelId,
      channelName: _channelName,
      showAppIconBadge: false,
    );
  }

  static Future<void> showItineraryNotification({
    required String title,
    required String body,
    String? payload,
  }) {
    return _showNotification(
      title: title,
      body: body,
      payload: payload,
      channelId: _itineraryChannelId,
      channelName: _itineraryChannelName,
      showAppIconBadge: true,
    );
  }

  static Future<void> _showNotification({
    required String title,
    required String body,
    required String channelId,
    required String channelName,
    required bool showAppIconBadge,
    String? payload,
  }) async {
    if (!_initialized || kIsWeb) return;

    final androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      importance: Importance.high,
      priority: Priority.high,
      channelShowBadge: showAppIconBadge,
      number: showAppIconBadge ? 1 : null,
    );
    final iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: showAppIconBadge,
      presentSound: true,
      badgeNumber: showAppIconBadge ? 1 : null,
    );
    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
      macOS: iosDetails,
    );

    await _plugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      details,
      payload: payload,
    );
  }

  static Future<void> scheduleItineraryReminder({
    required int id,
    required String title,
    required String body,
    required DateTime when,
    String? payload,
    /// Solo da un gesto esplicito (toggle Notifiche itinerario). Mai all'avvio.
    bool allowSystemPrompts = false,
  }) async {
    if (kIsWeb) return;
    await initialize();
    await _ensureTimeZones();

    final granted = await ensurePermission(allowPrompt: allowSystemPrompts);
    if (!granted) {
      throw StateError('Permesso notifiche non concesso.');
    }

    final exactAllowed = await hasExactAlarmPermission();
    if (allowSystemPrompts && !exactAllowed) {
      await requestExactAlarmPermission();
    }
    final useExact = exactAllowed || await hasExactAlarmPermission();

    const androidDetails = AndroidNotificationDetails(
      _itineraryChannelId,
      _itineraryChannelName,
      importance: Importance.high,
      priority: Priority.high,
      channelShowBadge: true,
      number: 1,
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      badgeNumber: 1,
    );
    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
      macOS: iosDetails,
    );

    await _plugin.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(when, tz.local),
      details,
      androidScheduleMode: useExact
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle,
      payload: payload,
    );
  }

  /// Android: permesso «Sveglie e promemoria» già concesso (senza aprire impostazioni).
  static Future<bool> hasExactAlarmPermission() async {
    if (defaultTargetPlatform != TargetPlatform.android) return true;
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return false;
    return await android.canScheduleExactNotifications() ?? false;
  }

  /// Apre le impostazioni Android «Sveglie e promemoria» — solo su scelta utente.
  static Future<void> requestExactAlarmPermission() async {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    await initialize();
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return;
    final canSchedule = await android.canScheduleExactNotifications();
    if (canSchedule == true) return;
    await android.requestExactAlarmsPermission();
  }

  static Future<void> cancelScheduled(int id) async {
    if (kIsWeb) return;
    if (!_initialized) return;
    await _plugin.cancel(id);
  }

  static Future<void> cancelAllScheduled() async {
    if (kIsWeb) return;
    if (!_initialized) {
      await initialize();
    }
    await _plugin.cancelAll();
  }
}
