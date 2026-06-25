import 'dart:async';

import 'package:flutter/foundation.dart';

import 'develop_sync_config.dart';
import 'develop_sync_device.dart';
import 'develop_sync_engine.dart';
import 'develop_sync_firestore.dart';
import 'develop_sync_sqlite_store.dart';
import 'develop_sync_status.dart';
import 'develop_sync_wire_record.dart';
import 'models/develop_local_collection.dart';

/// Orchestrazione sync multi-dispositivo (debounce push + listener remoto).
class DevelopSyncService {
  DevelopSyncService._();

  static final DevelopSyncService instance = DevelopSyncService._();

  final _statusController = StreamController<DevelopSyncStatus>.broadcast();
  DevelopSyncEngine? _engine;
  DevelopSyncFirestore? _remote;
  StreamSubscription<List<DevelopSyncWireRecord>>? _remoteSub;
  Timer? _pushDebounce;
  bool _running = false;
  bool _syncInProgress = false;
  DevelopSyncStatus _status = DevelopSyncStatus.idle;

  VoidCallback? onDataChanged;

  Stream<DevelopSyncStatus> get statusStream => _statusController.stream;
  DevelopSyncStatus get status => _status;
  bool get isRunning => _running;

  Future<void> start(DevelopSyncSqliteStore store) async {
    if (_running && _engine != null) return;

    _remote = DevelopSyncFirestore(store.userId);
    _engine = DevelopSyncEngine(store: store, remote: _remote!);
    _running = true;

    store.onMutation = _onLocalMutation;

    _setStatus(DevelopSyncState.syncing);
    try {
      await _remote!.registerDevice();
      final result = await _engine!.fullSync();
      if (result.pulled > 0) onDataChanged?.call();
      _setStatus(DevelopSyncState.idle, lastSuccessAt: DateTime.now());
    } catch (e, st) {
      debugPrint('DevelopSyncService: sync iniziale fallita ($e)\n$st');
      _setStatus(DevelopSyncState.error, errorMessage: e.toString());
    }

    await _startRemoteListener(store);
  }

  Future<void> _startRemoteListener(DevelopSyncSqliteStore store) async {
    await _remoteSub?.cancel();
    final lastPulled = int.tryParse(
          await store.getMeta(DevelopSyncConfig.metaLastPulledMs) ?? '0',
        ) ??
        0;

    _remoteSub = _remote!
        .watchRemoteChanges(lastPulled)
        .listen((wires) async {
      if (wires.isEmpty || _syncInProgress) return;
      final deviceId = await DevelopSyncDevice.id();
      final hasForeign = wires.any((w) => w.deviceId != deviceId);
      if (!hasForeign) return;
      final result = await syncNow(silent: true);
      if (result != null && result.pulled > 0) onDataChanged?.call();
    }, onError: (Object e) {
      debugPrint('DevelopSyncService: listener remoto ($e)');
    });
  }

  void _onLocalMutation(
    DevelopLocalCollection collection,
    String id, {
    required bool deleted,
    DateTime? updatedAt,
  }) {
    if (!_running || _syncInProgress) return;
    if (deleted) {
      unawaited(
        _engine?.pushTombstone(
          collection: collection,
          recordId: id,
          updatedAt: updatedAt ?? DateTime.now(),
        ),
      );
      return;
    }
    schedulePush();
  }

  void schedulePush() {
    _pushDebounce?.cancel();
    _pushDebounce = Timer(
      const Duration(milliseconds: DevelopSyncConfig.pushDebounceMs),
      () => unawaited(pushNow()),
    );
  }

  Future<void> pushNow() async {
    final engine = _engine;
    if (engine == null || _syncInProgress) return;

    _syncInProgress = true;
    try {
      final pushed = await engine.pushAllLocal();
      if (pushed > 0) {
        await _remote?.touchDevice();
        _setStatus(DevelopSyncState.idle, lastSuccessAt: DateTime.now());
      }
    } catch (e) {
      debugPrint('DevelopSyncService: push fallito ($e)');
      _setStatus(DevelopSyncState.error, errorMessage: e.toString());
    } finally {
      _syncInProgress = false;
    }
  }

  Future<DevelopSyncRunResult?> syncNow({bool silent = false}) async {
    final engine = _engine;
    if (engine == null) return null;

    if (!silent) _setStatus(DevelopSyncState.syncing);
    _syncInProgress = true;
    try {
      final result = await engine.fullSync();
      _setStatus(DevelopSyncState.idle, lastSuccessAt: DateTime.now());
      return result;
    } catch (e, st) {
      debugPrint('DevelopSyncService: syncNow fallita ($e)\n$st');
      _setStatus(DevelopSyncState.error, errorMessage: e.toString());
      return null;
    } finally {
      _syncInProgress = false;
    }
  }

  Future<void> stop() async {
    _pushDebounce?.cancel();
    _pushDebounce = null;
    await _remoteSub?.cancel();
    _remoteSub = null;
    _engine = null;
    _remote = null;
    _running = false;
    _syncInProgress = false;
    onDataChanged = null;
    _setStatus(DevelopSyncState.idle);
  }

  void _setStatus(
    DevelopSyncState state, {
    DateTime? lastSuccessAt,
    String? errorMessage,
  }) {
    _status = DevelopSyncStatus(
      state: state,
      lastSuccessAt: lastSuccessAt ?? _status.lastSuccessAt,
      errorMessage: errorMessage,
    );
    if (!_statusController.isClosed) {
      _statusController.add(_status);
    }
  }
}
