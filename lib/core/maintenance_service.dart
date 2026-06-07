import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Sezioni configurabili da BackOffice (`settings/maintenance`).
abstract final class MaintenanceService {
  static const all = 'Tutto';
  static const creditForm = 'CreditForm';
  static const creditJob = 'CreditJob';
  static const creditCalc = 'CreditCalc';
  static const area = 'Area riservata';

  static final ValueNotifier<Map<String, dynamic>?> data =
      ValueNotifier<Map<String, dynamic>?>(null);

  static StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _subscription;

  static DocumentReference<Map<String, dynamic>> get _doc =>
      FirebaseFirestore.instance.collection('settings').doc('maintenance');

  /// Avvia ascolto Firestore (idempotente).
  static void start() {
    if (_subscription != null) return;

    unawaited(_loadFromServer());

    _subscription = _doc.snapshots().listen(
      (snapshot) {
        final payload = snapshot.data();
        data.value = payload;
        if (kDebugMode) {
          debugPrint(
            '[Maintenance] enabled=${isEnabled(payload)} '
            'section=${blockedSectionName(payload)} '
            'blockedCreditCalc=${isSectionBlocked(payload, creditCalc)}',
          );
        }
      },
      onError: (Object error, StackTrace stack) {
        if (kDebugMode) {
          debugPrint('[Maintenance] snapshots error: $error');
        }
      },
    );
  }

  static void stop() {
    _subscription?.cancel();
    _subscription = null;
    data.value = null;
  }

  static Future<void> _loadFromServer() async {
    try {
      final snapshot = await _doc.get(const GetOptions(source: Source.server));
      data.value = snapshot.data();
    } catch (error) {
      if (kDebugMode) {
        debugPrint('[Maintenance] server get error: $error');
      }
    }
  }

  /// Compatibilità con codice che usa ancora StreamBuilder.
  static Stream<DocumentSnapshot<Map<String, dynamic>>> watch() {
    start();
    return _doc.snapshots();
  }

  static Map<String, dynamic>? dataFrom(
    DocumentSnapshot<Map<String, dynamic>>? snapshot,
  ) {
    return snapshot?.data();
  }

  static bool isEnabled(Map<String, dynamic>? payload) {
    if (payload == null) return false;

    final raw = payload['enabled'];
    if (raw is bool) return raw;
    if (raw is num) return raw != 0;
    if (raw is String) {
      final normalized = raw.trim().toLowerCase();
      return normalized == 'true' || normalized == '1';
    }
    return false;
  }

  static String blockedSectionName(Map<String, dynamic>? payload) {
    final section = payload?['section']?.toString().trim();
    if (section == null || section.isEmpty) return all;
    return section;
  }

  static bool isSectionBlocked(
    Map<String, dynamic>? payload,
    String sectionName,
  ) {
    if (!isEnabled(payload)) return false;

    final blocked = blockedSectionName(payload);
    if (blocked == all) return true;
    return blocked == sectionName;
  }

  static bool get isCreditCalcBlocked =>
      isSectionBlocked(data.value, creditCalc);
}
