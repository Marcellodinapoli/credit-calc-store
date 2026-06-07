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

  // ---------------------------------------------------------------------------
  // RESET (FUTURO / ADMIN)
  // ---------------------------------------------------------------------------
  static Future<void> resetAll() async {
    try {
      await _doc.set({
        'activeTab': 0,
        'telefonata': {},
        'contestazioni': {},
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
