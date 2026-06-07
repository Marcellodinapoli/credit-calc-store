import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Preferenze UI provvigioni (anteprima importo). Stesso comportamento di Planet.
abstract final class CommissionUiPreferences {
  static const _commissionsPreviewPrefsKey = 'commissions_preview_visible';

  static final _auth = FirebaseAuth.instance;
  static final _firestore = FirebaseFirestore.instance;
  static Map<String, dynamic>? _cache;

  static DocumentReference<Map<String, dynamic>>? get _userDoc {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;
    return _firestore.collection('users').doc(uid);
  }

  static Future<Map<String, dynamic>> _load() async {
    if (_cache != null) return _cache!;
    final doc = _userDoc;
    if (doc == null) return _cache = {};
    try {
      final snap = await doc.get();
      final raw = snap.data()?['readState'];
      if (raw is Map<String, dynamic>) {
        return _cache = Map<String, dynamic>.from(raw);
      }
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        debugPrint('CommissionUiPreferences._load → permission-denied');
        return _cache = {};
      }
      rethrow;
    }
    return _cache = {};
  }

  static Future<void> _persist(Map<String, dynamic> state) async {
    _cache = state;
    final doc = _userDoc;
    if (doc == null) return;
    try {
      await doc.set({'readState': state}, SetOptions(merge: true));
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        debugPrint('CommissionUiPreferences._persist → permission-denied');
        return;
      }
      rethrow;
    }
  }

  static Future<bool?> _commissionsPreviewFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (!prefs.containsKey(_commissionsPreviewPrefsKey)) return null;
    return prefs.getBool(_commissionsPreviewPrefsKey);
  }

  static Future<void> _persistCommissionsPreviewPrefs(bool visible) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_commissionsPreviewPrefsKey, visible);
  }

  static Future<bool> getCommissionsPreviewVisible() async {
    final local = await _commissionsPreviewFromPrefs();
    if (local != null) return local;

    final state = await _load();
    final value = state['commissionsPreviewVisible'];
    if (value is bool) {
      await _persistCommissionsPreviewPrefs(value);
      return value;
    }
    return true;
  }

  static Future<void> setCommissionsPreviewVisible(bool visible) async {
    await _persistCommissionsPreviewPrefs(visible);
    final state = await _load();
    state['commissionsPreviewVisible'] = visible;
    await _persist(state);
  }
}
