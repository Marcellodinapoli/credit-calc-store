import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/credit_calc_mode.dart';
import 'connectivity_service.dart';
import 'mode_preferences_service.dart';
import 'session_service.dart';
import 'sync_engine.dart';

/// Ascolta Firebase e aggiorna il DB locale in tempo reale (solo sessione attiva).
class RealtimeSyncService {
  RealtimeSyncService({
    required this.userId,
    required this.modePrefs,
    required this.sessionService,
    required this.syncEngine,
    required this.onDataChanged,
  });

  final String userId;
  final ModePreferencesService modePrefs;
  final SessionService sessionService;
  final SyncEngine syncEngine;
  final VoidCallback onDataChanged;

  final _firestore = FirebaseFirestore.instance;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _creditorsSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _calculationsSub;
  bool _running = false;

  bool get isRunning => _running;

  Future<void> refresh() async {
    final mode = await modePrefs.localMode();
    if (mode != CreditCalcMode.offlineSync) {
      stop();
      return;
    }
    if (!await ConnectivityService.isOnline()) {
      stop();
      return;
    }
    if (!await sessionService.holdsActiveSession()) {
      stop();
      return;
    }
    if (_running) return;
    _running = true;

    _creditorsSub = _firestore
        .collection('creditors')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .listen(
          (snap) => _handleSnapshot('creditors', snap),
          onError: (_) => stop(),
        );

    _calculationsSub = _firestore
        .collection('calculations')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .listen(
          (snap) => _handleSnapshot('calculations', snap),
          onError: (_) => stop(),
        );
  }

  Future<void> _handleSnapshot(
    String collection,
    QuerySnapshot<Map<String, dynamic>> snap,
  ) async {
    if (!await sessionService.holdsActiveSession()) {
      stop();
      return;
    }

    var changed = false;
    for (final change in snap.docChanges) {
      final applied = await syncEngine.applyRemoteChange(
        collection: collection,
        changeType: change.type,
        id: change.doc.id,
        data: change.doc.data(),
      );
      if (applied) changed = true;
    }
    if (changed) onDataChanged();
  }

  void stop() {
    _creditorsSub?.cancel();
    _calculationsSub?.cancel();
    _creditorsSub = null;
    _calculationsSub = null;
    _running = false;
  }

  void dispose() => stop();
}
