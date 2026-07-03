import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persistenza stato "letto" per Community e Assistenza (Firestore).
/// Sostituisce localStorage così la cache del browser non resetta i badge.
class ReadStateService {
  ReadStateService._();

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
        debugPrint('ReadStateService._load → permission-denied');
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
        debugPrint('ReadStateService._persist → permission-denied');
        return;
      }
      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  // ASSISTENZA DIRETTA
  // ---------------------------------------------------------------------------

  static Future<int> getSupportLastSeenMs() async {
    final state = await _load();
    return (state['supportLastSeenMs'] as num?)?.toInt() ?? 0;
  }

  static Future<void> setSupportLastSeenMs(int ms) async {
    final state = await _load();
    state['supportLastSeenMs'] = ms;
    await _persist(state);
  }

  static Future<Set<String>> getSupportTicketsSeen() async {
    final state = await _load();
    final list = state['supportTicketsSeen'];
    if (list is List) {
      return list.map((e) => e.toString()).toSet();
    }
    return {};
  }

  static Future<void> addSupportTicketSeen(String ticketId) async {
    final state = await _load();
    final list = (state['supportTicketsSeen'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        <String>[];
    if (!list.contains(ticketId)) {
      list.add(ticketId);
      state['supportTicketsSeen'] = list;
      await _persist(state);
    }
  }

  // ---------------------------------------------------------------------------
  // COMMUNITY
  // ---------------------------------------------------------------------------

  static Future<Map<String, int>> getCommunityTopicsLastSeen() async {
    final state = await _load();
    final raw = state['communityTopics'];
    if (raw is! Map) return {};

    return raw.map(
      (key, value) => MapEntry(key.toString(), (value as num).toInt()),
    );
  }

  static Future<int> getCommunityTopicLastSeenMs(String topicId) async {
    final topics = await getCommunityTopicsLastSeen();
    return topics[topicId] ?? 0;
  }

  static Future<void> setCommunityTopicLastSeenMs(String topicId, int ms) async {
    final state = await _load();
    final topics = Map<String, dynamic>.from(
      (state['communityTopics'] as Map<String, dynamic>?) ?? {},
    );
    topics[topicId] = ms;
    state['communityTopics'] = topics;
    await _persist(state);
  }

  /// Prima visita senza stato salvato: marca tutto come già letto.
  static Future<void> ensureSupportInitialized(int defaultLastSeenMs) async {
    final state = await _load();
    if (state.containsKey('supportLastSeenMs')) return;
    state['supportLastSeenMs'] = defaultLastSeenMs;
    await _persist(state);
  }

  static Future<void> ensureCommunityTopicInitialized(
    String topicId,
    int defaultLastSeenMs,
  ) async {
    final state = await _load();
    final topics = Map<String, dynamic>.from(
      (state['communityTopics'] as Map<String, dynamic>?) ?? {},
    );
    if (topics.containsKey(topicId)) return;
    topics[topicId] = defaultLastSeenMs;
    state['communityTopics'] = topics;
    await _persist(state);
  }

  // ---------------------------------------------------------------------------
  // CREDITFORM — ROLEPLAY
  // ---------------------------------------------------------------------------

  static Future<int> getRoleplayLastSeenMs() async {
    final state = await _load();
    return (state['roleplayLastSeenMs'] as num?)?.toInt() ?? 0;
  }

  static Future<void> setRoleplayLastSeenMs(int ms) async {
    final state = await _load();
    state['roleplayLastSeenMs'] = ms;
    await _persist(state);
  }

  /// Prima visita senza stato salvato: marca tutto come già letto.
  static Future<void> ensureRoleplayInitialized(int defaultLastSeenMs) async {
    final state = await _load();
    if (state.containsKey('roleplayLastSeenMs')) return;
    state['roleplayLastSeenMs'] = defaultLastSeenMs;
    await _persist(state);
  }

  // ---------------------------------------------------------------------------
  // CREDITJOB — OFFERTE DI LAVORO
  // ---------------------------------------------------------------------------

  static Future<int> getJobOffersLastSeenMs() async {
    final state = await _load();
    return (state['jobOffersLastSeenMs'] as num?)?.toInt() ?? 0;
  }

  static Future<void> setJobOffersLastSeenMs(int ms) async {
    final state = await _load();
    state['jobOffersLastSeenMs'] = ms;
    await _persist(state);
  }

  /// Prima visita senza stato salvato: marca tutto come già letto.
  static Future<void> ensureJobOffersInitialized(int defaultLastSeenMs) async {
    final state = await _load();
    if (state.containsKey('jobOffersLastSeenMs')) return;
    state['jobOffersLastSeenMs'] = defaultLastSeenMs;
    await _persist(state);
  }

  // ---------------------------------------------------------------------------
  // CREDITCALC — PROVVIGIONI (anteprima importo)
  // ---------------------------------------------------------------------------

  static const _commissionsPreviewPrefsKey = 'commissions_preview_visible';

  static Future<bool?> _commissionsPreviewFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (!prefs.containsKey(_commissionsPreviewPrefsKey)) return null;
    return prefs.getBool(_commissionsPreviewPrefsKey);
  }

  static Future<void> _persistCommissionsPreviewPrefs(bool visible) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_commissionsPreviewPrefsKey, visible);
  }

  /// `true` = mostra l'importo provvigionato in anteprima (default).
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
    _cache = state;

    final doc = _userDoc;
    if (doc == null) return;

    try {
      // Aggiorna solo il campo necessario (non sovrascrive tutto readState).
      await doc.update({'readState.commissionsPreviewVisible': visible});
    } on FirebaseException catch (e) {
      if (e.code == 'not-found') {
        try {
          await doc.set(
            {'readState': {'commissionsPreviewVisible': visible}},
            SetOptions(merge: true),
          );
        } on FirebaseException catch (e2) {
          if (e2.code == 'permission-denied') {
            debugPrint(
              'ReadStateService.setCommissionsPreviewVisible → permission-denied',
            );
          } else {
            rethrow;
          }
        }
      } else if (e.code == 'permission-denied') {
        debugPrint(
          'ReadStateService.setCommissionsPreviewVisible → permission-denied',
        );
      } else {
        rethrow;
      }
    }
  }

  static void clearCache() => _cache = null;
}
