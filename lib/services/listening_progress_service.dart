import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// -----------------------------------------------------------------------------
/// LISTENING PROGRESS SERVICE
/// Responsabilità: persistenza avanzamento Listening (Firestore)
/// -----------------------------------------------------------------------------
class ListeningProgressService {
  ListeningProgressService._();

  static final _auth = FirebaseAuth.instance;
  static final _firestore = FirebaseFirestore.instance;

  /// ID documento progressi
  static String get _docId => _auth.currentUser!.uid;

  /// Riferimento documento
  static DocumentReference<Map<String, dynamic>> get _doc =>
      _firestore.collection('listening_progress').doc(_docId);

  /// Trascrizioni warm-up telefonata della sessione corrente (non persistite).
  static final Map<String, String> _telefonataSessionResponses = {};

  // ---------------------------------------------------------------------------
  // INIT (SAFE)
  // ---------------------------------------------------------------------------
  static Future<void> initIfNeeded() async {
    try {
      final snap = await _doc.get();
      if (!snap.exists) {
        await _doc.set({
          'uid': _auth.currentUser!.uid,
          'activeTab': 0,
          'telefonata': {},
          'contestazioni': {},
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        debugPrint(
            'ListeningProgressService.initIfNeeded → permission-denied');
        return;
      }
      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  // TAB
  // ---------------------------------------------------------------------------
  static Future<int> getActiveTab() async {
    try {
      final snap = await _doc.get();
      return snap.data()?['activeTab'] ?? 0;
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        return 0;
      }
      rethrow;
    }
  }

  static Future<void> setActiveTab(int index) async {
    try {
      await _doc.set({
        'activeTab': index,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        return;
      }
      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  // TELEFONATA
  // ---------------------------------------------------------------------------
  static Future<Map<String, bool>> getTelefonataProgress() async {
    try {
      final snap = await _doc.get();
      final data = snap.data()?['telefonata'] as Map<String, dynamic>? ?? {};
      return data.map((k, v) => MapEntry(k, v as bool));
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        return {};
      }
      rethrow;
    }
  }

  static Future<void> setTelefonataCompleted(String phase) async {
    try {
      await _doc.set({
        'telefonata': {phase: true},
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        return;
      }
      rethrow;
    }
  }

  static Future<void> setTelefonataResponse(
    String phase,
    String transcription,
  ) async {
    final trimmed = transcription.trim();
    if (trimmed.isEmpty) return;
    _telefonataSessionResponses[phase] = trimmed;
  }

  static Future<String?> getTelefonataResponse(String phase) async {
    final value = _telefonataSessionResponses[phase];
    if (value == null) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  static void clearTelefonataSession() {
    _telefonataSessionResponses.clear();
  }

  /// Salva (sovrascrivendo) la valutazione AI della fase telefonata.
  static Future<void> setTelefonataEvaluation(
    String phase,
    Map<String, dynamic> result,
  ) async {
    try {
      await _doc.set({
        'telefonataEvaluations': {
          phase: {
            'result': result,
            'evaluatedAtMs': DateTime.now().millisecondsSinceEpoch,
          },
        },
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        return;
      }
      rethrow;
    }
  }

  static Future<WarmupSavedEvaluation?> getTelefonataEvaluation(
    String phase,
  ) async {
    try {
      final snap = await _doc.get();
      final data =
          snap.data()?['telefonataEvaluations'] as Map<String, dynamic>? ?? {};
      return WarmupSavedEvaluation.fromRaw(data[phase]);
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        return null;
      }
      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  // CONTESTAZIONI
  // ---------------------------------------------------------------------------
  static Future<Map<String, bool>> getContestazioniProgress() async {
    try {
      final snap = await _doc.get();
      final data =
          snap.data()?['contestazioni'] as Map<String, dynamic>? ?? {};
      return data.map((k, v) => MapEntry(k, v as bool));
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        return {};
      }
      rethrow;
    }
  }

  static Future<void> setContestationCompleted(
      String contestationId) async {
    try {
      await _doc.set({
        'contestazioni': {contestationId: true},
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        return;
      }
      rethrow;
    }
  }

  static Future<void> setContestationResponse(
    String contestationKey,
    String transcription,
  ) async {
    final trimmed = transcription.trim();
    if (trimmed.isEmpty) return;

    try {
      await _doc.set({
        'contestazioneResponses': {contestationKey: trimmed},
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        return;
      }
      rethrow;
    }
  }

  static Future<String?> getContestationResponse(String contestationKey) async {
    try {
      final snap = await _doc.get();
      final data =
          snap.data()?['contestazioneResponses'] as Map<String, dynamic>? ??
              {};
      final value = data[contestationKey];
      if (value is! String) return null;
      final trimmed = value.trim();
      return trimmed.isEmpty ? null : trimmed;
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        return null;
      }
      rethrow;
    }
  }

  static Future<void> setContestationEvaluation(
    String contestationKey,
    Map<String, dynamic> result,
  ) async {
    try {
      await _doc.set({
        'contestazioneEvaluations': {
          contestationKey: {
            'result': result,
            'evaluatedAtMs': DateTime.now().millisecondsSinceEpoch,
          },
        },
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        return;
      }
      rethrow;
    }
  }

  static Future<WarmupSavedEvaluation?> getContestationEvaluation(
    String contestationKey,
  ) async {
    try {
      final snap = await _doc.get();
      final data =
          snap.data()?['contestazioneEvaluations'] as Map<String, dynamic>? ??
              {};
      return WarmupSavedEvaluation.fromRaw(data[contestationKey]);
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        return null;
      }
      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  // RESET (FUTURO / ADMIN)
  // ---------------------------------------------------------------------------
  static Future<void> resetAll() async {
    clearTelefonataSession();
    try {
      await _doc.set({
        'activeTab': 0,
        'telefonata': {},
        'contestazioni': {},
        'telefonataResponses': {},
        'telefonataEvaluations': {},
        'contestazioneResponses': {},
        'contestazioneEvaluations': {},
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        return;
      }
      rethrow;
    }
  }
}

/// Valutazione AI salvata (telefonata / contestazione).
class WarmupSavedEvaluation {
  const WarmupSavedEvaluation({
    required this.result,
    required this.evaluatedAt,
  });

  final Map<String, dynamic> result;
  final DateTime evaluatedAt;

  static WarmupSavedEvaluation? fromRaw(dynamic raw) {
    if (raw is! Map) return null;
    final map = Map<String, dynamic>.from(raw);
    final resultRaw = map['result'];
    if (resultRaw is! Map) return null;
    final ms = map['evaluatedAtMs'];
    final evaluatedAt = ms is int
        ? DateTime.fromMillisecondsSinceEpoch(ms)
        : DateTime.tryParse(ms?.toString() ?? '') ?? DateTime.now();
    return WarmupSavedEvaluation(
      result: Map<String, dynamic>.from(resultRaw),
      evaluatedAt: evaluatedAt,
    );
  }

  String get formattedDateTime {
    final d = evaluatedAt;
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    final yy = d.year.toString();
    final hh = d.hour.toString().padLeft(2, '0');
    final min = d.minute.toString().padLeft(2, '0');
    return '$dd/$mm/$yy $hh:$min';
  }
}
