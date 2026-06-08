import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/credit_calc_mode.dart';
import 'local_database_service.dart';

/// Persistenza della modalità CreditCalc (locale + Firestore).
class ModePreferencesService {
  ModePreferencesService({required this.userId});

  final String userId;

  String get _localModeKey => 'credit_calc_mode_$userId';
  String get _localModeChosenKey => 'credit_calc_mode_chosen_$userId';
  String get _localInitialSyncKey => 'credit_calc_initial_sync_done_$userId';

  Future<CreditCalcMode?> localMode() async {
    final prefs = await SharedPreferences.getInstance();
    final perUser = prefs.getString(_localModeKey);
    if (perUser != null) {
      return CreditCalcModeCodec.fromStorage(perUser);
    }
    // Migrazione chiavi globali legacy.
    return CreditCalcModeCodec.fromStorage(
      prefs.getString('credit_calc_mode'),
    );
  }

  Future<bool> hasChosenModeLocally() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.containsKey(_localModeChosenKey)) {
      return prefs.getBool(_localModeChosenKey) ?? false;
    }
    return prefs.getBool('credit_calc_mode_chosen') ?? false;
  }

  Future<bool> isInitialSyncDoneLocally() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_localInitialSyncKey) ?? false;
  }

  /// Imposta sempre Offline + Sync (migra utenti legacy in modalità Web).
  Future<void> ensureOfflineSyncMode() async {
    final current = await localMode();
    if (current != CreditCalcMode.offlineSync || !await hasChosenModeLocally()) {
      await saveMode(CreditCalcMode.offlineSync);
    }
  }

  Future<void> saveMode(CreditCalcMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_localModeKey, mode.storageValue);
    await prefs.setBool(_localModeChosenKey, true);

    try {
      await FirebaseFirestore.instance.collection('users').doc(userId).set(
        {
          'creditCalcMode': mode.storageValue,
          'creditCalcModeChosenAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } catch (_) {}
  }

  Future<void> markInitialSyncComplete({
    required int recordCount,
    required String dataVersion,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_localInitialSyncKey, true);

    try {
      await FirebaseFirestore.instance.collection('users').doc(userId).set(
        {
          'creditCalcInitialSyncComplete': true,
          'creditCalcLastSyncAt': FieldValue.serverTimestamp(),
          'creditCalcDataVersion': dataVersion,
          'creditCalcLocalRecordCount': recordCount,
        },
        SetOptions(merge: true),
      );
    } catch (_) {}

    await LocalDatabaseService.instance.setMeta(
      'initial_sync_done_$userId',
      'true',
    );
    await LocalDatabaseService.instance.setMeta(
      'last_sync_at_$userId',
      DateTime.now().toIso8601String(),
    );
  }

  Future<DateTime?> lastSyncAt() async {
    final raw =
        await LocalDatabaseService.instance.getMeta('last_sync_at_$userId');
    if (raw == null) return null;
    return DateTime.tryParse(raw);
  }

  Future<void> updateLastSyncAt() async {
    final now = DateTime.now();
    await LocalDatabaseService.instance.setMeta(
      'last_sync_at_$userId',
      now.toIso8601String(),
    );
    try {
      await FirebaseFirestore.instance.collection('users').doc(userId).set(
        {'creditCalcLastSyncAt': FieldValue.serverTimestamp()},
        SetOptions(merge: true),
      );
    } catch (_) {}
  }

  Future<void> resetInitialSyncFlag() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_localInitialSyncKey, false);
    try {
      await FirebaseFirestore.instance.collection('users').doc(userId).set(
        {'creditCalcInitialSyncComplete': false},
        SetOptions(merge: true),
      );
    } catch (_) {}
  }
}
