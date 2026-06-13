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

    await _plugin.initialize(initSettings);
    await _ensureTimeZones();

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

  static Future<void> showProductNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    if (!_initialized || kIsWeb) return;

    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      importance: Importance.high,
      priority: Priority.high,
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
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
  }) async {
    if (!_initialized || kIsWeb) return;
    await _ensureTimeZones();

    const androidDetails = AndroidNotificationDetails(
      _itineraryChannelId,
      _itineraryChannelName,
      importance: Importance.high,
      priority: Priority.high,
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _plugin.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(when, tz.local),
      details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: payload,
    );
  }

  static Future<void> cancelScheduled(int id) async {
    if (!_initialized || kIsWeb) return;
    await _plugin.cancel(id);
  }
}
