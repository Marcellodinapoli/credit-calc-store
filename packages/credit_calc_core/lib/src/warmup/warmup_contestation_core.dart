import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

enum WarmupContestationContextCore {
  sollecito,
  recupero;

  String get firestoreValue => name;

  String get label => switch (this) {
        WarmupContestationContextCore.sollecito => 'Sollecito',
        WarmupContestationContextCore.recupero => 'Recupero',
      };

  static WarmupContestationContextCore fromString(String? raw) {
    return switch (raw) {
      'recupero' => WarmupContestationContextCore.recupero,
      _ => WarmupContestationContextCore.sollecito,
    };
  }
}

enum WarmupContestationStatusCore {
  draft,
  pendingReview,
  approved,
  rejected;

  String get firestoreValue => switch (this) {
        WarmupContestationStatusCore.draft => 'draft',
        WarmupContestationStatusCore.pendingReview => 'pending_review',
        WarmupContestationStatusCore.approved => 'approved',
        WarmupContestationStatusCore.rejected => 'rejected',
      };

  String get label => switch (this) {
        WarmupContestationStatusCore.draft => 'Bozza',
        WarmupContestationStatusCore.pendingReview => 'In valutazione',
        WarmupContestationStatusCore.approved => 'Condivisa',
        WarmupContestationStatusCore.rejected => 'Rifiutata',
      };

  static WarmupContestationStatusCore fromString(String? raw) {
    return switch (raw) {
      'pending_review' => WarmupContestationStatusCore.pendingReview,
      'approved' => WarmupContestationStatusCore.approved,
      'rejected' => WarmupContestationStatusCore.rejected,
      _ => WarmupContestationStatusCore.draft,
    };
  }
}

enum WarmupContestationCategoryCore {
  economica,
  legale,
  salute,
  amministrativa,
  generica;

  String get label => switch (this) {
        WarmupContestationCategoryCore.economica => 'Economica',
        WarmupContestationCategoryCore.legale => 'Legale',
        WarmupContestationCategoryCore.salute => 'Salute',
        WarmupContestationCategoryCore.amministrativa => 'Amministrativa',
        WarmupContestationCategoryCore.generica => 'Generica',
      };

  static WarmupContestationCategoryCore fromString(String? raw) {
    return WarmupContestationCategoryCore.values.firstWhere(
      (c) => c.name == raw,
      orElse: () => WarmupContestationCategoryCore.generica,
    );
  }
}

class WarmupContestationCore {
  const WarmupContestationCore({
    required this.id,
    required this.authorUid,
    this.authorName,
    required this.context,
    required this.status,
    required this.title,
    required this.declared,
    required this.meaning,
    required this.risk,
    required this.objective,
    required this.response,
    this.category = WarmupContestationCategoryCore.generica,
    this.createdAt,
    this.reviewedAt,
  });

  final String id;
  final String authorUid;
  final String? authorName;
  final WarmupContestationContextCore context;
  final WarmupContestationStatusCore status;
  final String title;
  final String declared;
  final String meaning;
  final String risk;
  final String objective;
  final String response;
  final WarmupContestationCategoryCore category;
  final DateTime? createdAt;
  final DateTime? reviewedAt;

  factory WarmupContestationCore.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    return WarmupContestationCore(
      id: doc.id,
      authorUid: (data['authorUid'] ?? '').toString(),
      authorName: data['authorName']?.toString(),
      context: WarmupContestationContextCore.fromString(
        data['context']?.toString(),
      ),
      status: WarmupContestationStatusCore.fromString(
        data['status']?.toString(),
      ),
      title: (data['title'] ?? '').toString(),
      declared: (data['declared'] ?? '').toString(),
      meaning: (data['meaning'] ?? '').toString(),
      risk: (data['risk'] ?? '').toString(),
      objective: (data['objective'] ?? '').toString(),
      response: (data['response'] ?? '').toString(),
      category: WarmupContestationCategoryCore.fromString(
        data['category']?.toString(),
      ),
      createdAt: _readTimestamp(data['createdAt']),
      reviewedAt: _readTimestamp(data['reviewedAt']),
    );
  }

  static DateTime? _readTimestamp(dynamic raw) {
    if (raw is Timestamp) return raw.toDate();
    return null;
  }
}

class WarmupContestationSheetsCore {
  const WarmupContestationSheetsCore({
    required this.meaning,
    required this.risk,
    required this.objective,
    required this.response,
    required this.category,
  });

  final String meaning;
  final String risk;
  final String objective;
  final String response;
  final WarmupContestationCategoryCore category;
}

abstract final class WarmupContestationAdminCore {
  static const collection = 'warmup_contestations';
  static const _region = 'europe-west1';
  static const _projectId = 'creditform-d505d';

  static final _firestore = FirebaseFirestore.instance;

  static Stream<List<WarmupContestationCore>> watchPendingReview() {
    return _firestore
        .collection(collection)
        .where('status', isEqualTo: 'pending_review')
        .snapshots()
        .map(
          (snap) => snap.docs.map(WarmupContestationCore.fromDoc).toList()
            ..sort((a, b) {
              final at = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
              final bt = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
              return bt.compareTo(at);
            }),
        );
  }

  static Stream<List<WarmupContestationCore>> watchApprovedByContext(
    String context,
  ) {
    return _firestore
        .collection(collection)
        .where('status', isEqualTo: 'approved')
        .snapshots()
        .map(
          (snap) => snap.docs
              .map(WarmupContestationCore.fromDoc)
              .where((item) => item.context.firestoreValue == context)
              .toList()
            ..sort((a, b) {
              final at = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
              final bt = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
              return bt.compareTo(at);
            }),
        );
  }

  static Future<void> approve(String id) async {
    await _firestore.collection(collection).doc(id).update({
      'status': WarmupContestationStatusCore.approved.firestoreValue,
      'rejectionNote': FieldValue.delete(),
      'reviewedAt': FieldValue.serverTimestamp(),
      'reviewedBy': 'admin',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> reject({
    required String id,
    String? note,
  }) async {
    await _firestore.collection(collection).doc(id).update({
      'status': WarmupContestationStatusCore.rejected.firestoreValue,
      'rejectionNote': (note ?? '').trim().isEmpty ? null : note!.trim(),
      'reviewedAt': FieldValue.serverTimestamp(),
      'reviewedBy': 'admin',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> delete(String id) async {
    await _firestore.collection(collection).doc(id).delete();
  }

  static Future<void> ensureSheets(WarmupContestationCore item) async {
    if (_hasCompleteSheets(item)) return;
    final sheets = await generateSheets(
      declared: item.declared,
      context: item.context,
    );
    await _firestore.collection(collection).doc(item.id).update({
      'meaning': sheets.meaning,
      'risk': sheets.risk,
      'objective': sheets.objective,
      'response': sheets.response,
      'category': sheets.category.name,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  static bool _hasCompleteSheets(WarmupContestationCore item) {
    return item.meaning.trim().isNotEmpty &&
        item.risk.trim().isNotEmpty &&
        item.objective.trim().isNotEmpty &&
        item.response.trim().isNotEmpty;
  }

  static Future<WarmupContestationSheetsCore> generateSheets({
    required String declared,
    required WarmupContestationContextCore context,
  }) async {
    final data = await _callFunction('contestationGenerate', {
      'declared': declared.trim(),
      'context': context.firestoreValue,
    });
    if (data is! Map) {
      throw Exception('Risposta non valida dal server.');
    }
    final map = Map<String, dynamic>.from(data);
    final meaning = (map['meaning'] ?? '').toString().trim();
    final risk = (map['risk'] ?? '').toString().trim();
    final objective = (map['objective'] ?? '').toString().trim();
    final response = (map['response'] ?? '').toString().trim();
    if (meaning.isEmpty ||
        risk.isEmpty ||
        objective.isEmpty ||
        response.isEmpty) {
      throw Exception('L\'AI non ha compilato tutte le schede di analisi.');
    }
    return WarmupContestationSheetsCore(
      meaning: meaning,
      risk: risk,
      objective: objective,
      response: response,
      category: WarmupContestationCategoryCore.fromString(
        map['category']?.toString(),
      ),
    );
  }

  static Future<String> save({
    String? id,
    required WarmupContestationContextCore context,
    required String declared,
    required WarmupContestationStatusCore status,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    final uid = user?.uid;
    if (uid == null) throw StateError('Sessione scaduta.');

    final trimmedDeclared = declared.trim();
    if (trimmedDeclared.isEmpty) {
      throw StateError('La contestazione dichiarata è obbligatoria.');
    }

    final title = _autoTitle(trimmedDeclared);
    final sheets = await generateSheets(
      declared: trimmedDeclared,
      context: context,
    );

    if (id == null) {
      final ref = await _firestore.collection(collection).add({
        'authorUid': uid,
        if (user?.displayName?.trim().isNotEmpty == true)
          'authorName': user!.displayName!.trim(),
        'context': context.firestoreValue,
        'status': status.firestoreValue,
        'title': title,
        'declared': trimmedDeclared,
        'meaning': sheets.meaning,
        'risk': sheets.risk,
        'objective': sheets.objective,
        'response': sheets.response,
        'userRawInput': trimmedDeclared,
        'category': sheets.category.name,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return ref.id;
    }

    await _firestore.collection(collection).doc(id).update({
      'context': context.firestoreValue,
      'status': status.firestoreValue,
      'title': title,
      'declared': trimmedDeclared,
      'meaning': sheets.meaning,
      'risk': sheets.risk,
      'objective': sheets.objective,
      'response': sheets.response,
      'userRawInput': trimmedDeclared,
      'category': sheets.category.name,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return id;
  }

  static String _autoTitle(String declared) {
    final text = declared.trim();
    if (text.length <= 48) return text;
    return '${text.substring(0, 45)}…';
  }

  static Future<dynamic> _callFunction(
    String name,
    Map<String, dynamic> data,
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw StateError('Utente non autenticato.');

    final token = await user.getIdToken();
    final url = Uri.parse(
      'https://$_region-$_projectId.cloudfunctions.net/$name',
    );

    final response = await http.post(
      url,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'data': data}),
    );

    Map<String, dynamic> payload;
    try {
      final decoded = jsonDecode(response.body);
      payload = decoded is Map<String, dynamic>
          ? decoded
          : Map<String, dynamic>.from(decoded as Map);
    } catch (_) {
      throw Exception(
        'Risposta non valida dal server (${response.statusCode}).',
      );
    }

    final error = payload['error'];
    if (error != null) {
      final message = error is Map
          ? (error['message'] ?? error['status']).toString()
          : error.toString();
      throw Exception(message.isNotEmpty ? message : 'Errore function.');
    }

    if (response.statusCode != 200) {
      throw Exception('HTTP ${response.statusCode}: ${response.body}');
    }

    return payload['result'];
  }
}
