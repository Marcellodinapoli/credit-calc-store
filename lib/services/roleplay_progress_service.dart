import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Progresso roleplay: ultima simulazione (collaboratori) + dettaglio per card.
abstract final class RoleplayProgressService {
  RoleplayProgressService._();

  static const collection = 'roleplay_progress';

  static DocumentReference<Map<String, dynamic>> _doc(String userId) =>
      FirebaseFirestore.instance.collection(collection).doc(userId);

  /// Salva/sovrascrive l'ultima simulazione completata o interrotta.
  static Future<void> saveLastSimulation({
    required String simulationId,
    required String title,
    required String category,
    required List<dynamic> practiceData,
    required int userExchanges,
    required int totalMessages,
    String? responderRole,
    String? familyRelation,
    bool privacyViolation = false,
    List<Map<String, String>> history = const [],
    int durationMs = 0,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final nowMs = DateTime.now().millisecondsSinceEpoch;
    try {
      await _doc(uid).set({
        'userId': uid,
        'simulationId': simulationId,
        'title': title,
        'category': category,
        'practiceData': practiceData,
        'userExchanges': userExchanges,
        'totalMessages': totalMessages,
        if (responderRole != null && responderRole.isNotEmpty)
          'responderRole': responderRole,
        if (familyRelation != null && familyRelation.isNotEmpty)
          'familyRelation': familyRelation,
        'privacyViolation': privacyViolation,
        'completedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (history.isNotEmpty && simulationId.isNotEmpty) {
        await _mergeSimulationDetail(
          uid: uid,
          simulationId: simulationId,
          history: history,
          conversationAtMs: nowMs,
          durationMs: durationMs,
          userExchanges: userExchanges,
        );
      }
    } on FirebaseException catch (e) {
      debugPrint('RoleplayProgressService.saveLastSimulation → ${e.code}');
    }
  }

  /// Salva (sovrascrivendo) il suggerimento AI per una simulazione.
  static Future<void> saveSimulationSuggestion({
    required String simulationId,
    required String suggestion,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || simulationId.isEmpty) return;
    final text = suggestion.trim();
    if (text.isEmpty) return;

    try {
      await _mergeSimulationDetail(
        uid: uid,
        simulationId: simulationId,
        suggestion: text,
        evaluatedAtMs: DateTime.now().millisecondsSinceEpoch,
      );
    } on FirebaseException catch (e) {
      debugPrint('RoleplayProgressService.saveSimulationSuggestion → ${e.code}');
    }
  }

  static Future<void> _mergeSimulationDetail({
    required String uid,
    required String simulationId,
    List<Map<String, String>>? history,
    int? conversationAtMs,
    String? suggestion,
    int? evaluatedAtMs,
    int? durationMs,
    int? userExchanges,
  }) async {
    final ref = _doc(uid);
    final snap = await ref.get();
    final root = Map<String, dynamic>.from(snap.data() ?? {});
    final simulations = Map<String, dynamic>.from(
      (root['simulations'] as Map?)?.cast<String, dynamic>() ?? {},
    );
    final current = Map<String, dynamic>.from(
      (simulations[simulationId] as Map?)?.cast<String, dynamic>() ?? {},
    );

    if (history != null) {
      current['history'] = history
          .map((m) => {
                'role': m['role'] ?? '',
                'content': m['content'] ?? '',
              })
          .toList();
    }
    if (conversationAtMs != null) {
      current['conversationAtMs'] = conversationAtMs;
    }
    if (suggestion != null) {
      current['suggestion'] = suggestion;
    }
    if (evaluatedAtMs != null) {
      current['evaluatedAtMs'] = evaluatedAtMs;
    }
    if (durationMs != null) {
      current['durationMs'] = durationMs;
    }
    if (userExchanges != null) {
      current['userExchanges'] = userExchanges;
    }
    current['updatedAtMs'] = DateTime.now().millisecondsSinceEpoch;

    simulations[simulationId] = current;
    // Sempre includere userId: le rules richiedono
    // request.resource.data.userId == uid anche su create del solo dettaglio.
    await ref.set({
      'userId': uid,
      'simulations': simulations,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static Stream<Map<String, RoleplaySimulationDetail>> watchSimulationDetails() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return Stream.value(const {});
    }
    return _doc(uid).snapshots().map((snap) {
      final data = snap.data() ?? {};
      final raw =
          (data['simulations'] as Map?)?.cast<String, dynamic>() ?? {};
      final out = <String, RoleplaySimulationDetail>{};
      for (final entry in raw.entries) {
        final detail = RoleplaySimulationDetail.fromMap(entry.value);
        if (detail != null) out[entry.key] = detail;
      }
      return out;
    });
  }

  static RoleplayLastSimulation? fromDoc(
    DocumentSnapshot<Map<String, dynamic>> snap,
  ) {
    if (!snap.exists) return null;
    final data = snap.data();
    if (data == null) return null;

    final title = (data['title'] ?? '').toString().trim();
    if (title.isEmpty) return null;

    return RoleplayLastSimulation(
      simulationId: (data['simulationId'] ?? '').toString(),
      title: title,
      category: (data['category'] ?? '').toString(),
      practiceData: List<Map<String, dynamic>>.from(
        (data['practiceData'] as List<dynamic>? ?? []).map(
          (e) => e is Map
              ? Map<String, dynamic>.from(e)
              : <String, dynamic>{},
        ),
      ),
      userExchanges: (data['userExchanges'] as num?)?.toInt() ?? 0,
      totalMessages: (data['totalMessages'] as num?)?.toInt() ?? 0,
      responderRole: (data['responderRole'] ?? '').toString().trim().isEmpty
          ? null
          : (data['responderRole'] ?? '').toString(),
      familyRelation: (data['familyRelation'] ?? '').toString().trim().isEmpty
          ? null
          : (data['familyRelation'] ?? '').toString(),
      privacyViolation: data['privacyViolation'] == true,
      completedAt: (data['completedAt'] as Timestamp?)?.toDate(),
    );
  }
}

class RoleplaySimulationDetail {
  /// Durata minima per poter sviluppare il suggerimento.
  static const minSuggestionDuration = Duration(seconds: 30);

  /// Almeno uno scambio utente, in alternativa alla sola durata.
  static const minSuggestionUserExchanges = 1;

  const RoleplaySimulationDetail({
    this.history = const [],
    this.suggestion,
    this.conversationAt,
    this.evaluatedAt,
    this.durationMs = 0,
    this.userExchanges = 0,
  });

  final List<Map<String, String>> history;
  final String? suggestion;
  final DateTime? conversationAt;
  final DateTime? evaluatedAt;
  final int durationMs;
  final int userExchanges;

  bool get hasConversation => history.isNotEmpty;
  bool get hasSuggestion => (suggestion ?? '').trim().isNotEmpty;

  bool get isLongEnoughForSuggestion =>
      durationMs >= minSuggestionDuration.inMilliseconds ||
      userExchanges >= minSuggestionUserExchanges;

  static RoleplaySimulationDetail? fromMap(dynamic raw) {
    if (raw is! Map) return null;
    final map = Map<String, dynamic>.from(raw);
    final historyRaw = map['history'];
    final history = <Map<String, String>>[];
    if (historyRaw is List) {
      for (final item in historyRaw) {
        if (item is! Map) continue;
        history.add({
          'role': (item['role'] ?? '').toString(),
          'content': (item['content'] ?? '').toString(),
        });
      }
    }
    final suggestion = (map['suggestion'] ?? '').toString().trim();
    final conversationMs = map['conversationAtMs'];
    final evaluatedMs = map['evaluatedAtMs'];
    final durationMs = (map['durationMs'] as num?)?.toInt() ?? 0;
    final exchanges = (map['userExchanges'] as num?)?.toInt() ??
        history.where((m) => m['role'] == 'user').length;
    return RoleplaySimulationDetail(
      history: history,
      suggestion: suggestion.isEmpty ? null : suggestion,
      conversationAt: conversationMs is int
          ? DateTime.fromMillisecondsSinceEpoch(conversationMs)
          : null,
      evaluatedAt: evaluatedMs is int
          ? DateTime.fromMillisecondsSinceEpoch(evaluatedMs)
          : null,
      durationMs: durationMs,
      userExchanges: exchanges,
    );
  }

  String formatHistoryPreview({int maxChars = 160}) {
    if (history.isEmpty) return '';
    final text = history.map((m) {
      final who = m['role'] == 'user' ? 'Tu' : 'AI';
      return '$who: ${m['content'] ?? ''}';
    }).join(' · ');
    if (text.length <= maxChars) return text;
    return '${text.substring(0, maxChars).trimRight()}…';
  }

  String formatSuggestionPreview({int maxChars = 160}) {
    final text = (suggestion ?? '').trim();
    if (text.length <= maxChars) return text;
    return '${text.substring(0, maxChars).trimRight()}…';
  }

  static String formatDateTime(DateTime value) {
    final dd = value.day.toString().padLeft(2, '0');
    final mm = value.month.toString().padLeft(2, '0');
    final yy = value.year.toString();
    final hh = value.hour.toString().padLeft(2, '0');
    final min = value.minute.toString().padLeft(2, '0');
    return '$dd/$mm/$yy $hh:$min';
  }

  static String formatDuration(int durationMs) {
    if (durationMs <= 0) return '';
    final totalSec = (durationMs / 1000).round();
    final minutes = totalSec ~/ 60;
    final seconds = totalSec % 60;
    if (minutes <= 0) return '$seconds sec';
    return '$minutes min ${seconds.toString().padLeft(2, '0')} sec';
  }
}

class RoleplayLastSimulation {
  const RoleplayLastSimulation({
    required this.simulationId,
    required this.title,
    required this.category,
    required this.practiceData,
    required this.userExchanges,
    required this.totalMessages,
    this.responderRole,
    this.familyRelation,
    this.privacyViolation = false,
    this.completedAt,
  });

  final String simulationId;
  final String title;
  final String category;
  final List<Map<String, dynamic>> practiceData;
  final int userExchanges;
  final int totalMessages;
  final String? responderRole;
  final String? familyRelation;
  final bool privacyViolation;
  final DateTime? completedAt;
}
