import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../pages/area/announcements_page.dart';
import '../pages/creditform/personal_form_menu.dart';
import '../pages/creditjob/personal_job_menu.dart';
import '../shell/credit_calc_shell_nav.dart';

/// Navigazione deep-link da tap su notifiche FCM / locali.
class NotificationNavigation {
  NotificationNavigation._();

  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  static Map<String, String>? _pending;
  static bool _shellReady = false;

  static void markShellReady() {
    _shellReady = true;
    flushPending();
  }

  static void markShellUnavailable() {
    _shellReady = false;
  }

  static void flushPending() {
    final pending = _pending;
    if (pending == null || !_shellReady) return;
    _pending = null;
    _navigate(pending);
  }

  /// Payload FCM (`message.data`) o mappa equivalente.
  static void openFromData(Map<String, dynamic> data) {
    final normalized = <String, String>{};
    data.forEach((key, value) {
      if (value == null) return;
      normalized[key] = value.toString();
    });
    if (normalized.isEmpty) return;

    if (!_shellReady || navigatorKey.currentState == null) {
      _pending = normalized;
      return;
    }
    _navigate(normalized);
  }

  static void openFromRemoteMessage(RemoteMessage message) {
    openFromData(message.data);
  }

  /// Payload stringa delle notifiche locali (`type:id` oppure solo id itinerario).
  static void openFromLocalPayload(String? payload) {
    if (payload == null || payload.trim().isEmpty) return;
    final raw = payload.trim();
    final colon = raw.indexOf(':');
    if (colon > 0) {
      final type = raw.substring(0, colon).trim();
      final id = raw.substring(colon + 1).trim();
      openFromData({'type': type, _idKeyForType(type): id});
      return;
    }
    // Reminder locali itinerario: solo id visita/promemoria.
    openFromData({'type': 'field_visit', 'visitId': raw});
  }

  static String encodeLocalPayload(String type, String id) => '$type:$id';

  static String _idKeyForType(String type) {
    switch (type) {
      case 'announcement':
        return 'announcementId';
      case 'course':
        return 'courseId';
      case 'job_offer':
        return 'offerId';
      case 'field_visit':
        return 'visitId';
      case 'field_reminder':
        return 'reminderId';
      default:
        return 'id';
    }
  }

  static void _navigate(Map<String, String> data) {
    final nav = navigatorKey.currentState;
    if (nav == null) {
      _pending = data;
      return;
    }

    final type = (data['type'] ?? '').trim();
    switch (type) {
      case 'announcement':
        nav.push(
          MaterialPageRoute<void>(
            builder: (_) => const AnnouncementsPage(),
          ),
        );
        return;
      case 'course':
        PersonalFormMenuItem.courses.open(nav.context);
        return;
      case 'job_offer':
        PersonalJobMenuItem.jobOffers.open(nav.context);
        return;
      case 'field_visit':
      case 'field_reminder':
        creditCalcActiveSection.value = CreditCalcNavItem.tools;
        return;
      default:
        if (kDebugMode) {
          debugPrint('NotificationNavigation: tipo sconosciuto "$type"');
        }
    }
  }
}
