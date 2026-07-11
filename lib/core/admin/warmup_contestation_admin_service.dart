import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../models/warmup_contestation.dart';
import '../../services/warmup_contestation_service.dart';
import 'bk_admin_service.dart';

/// Moderazione contestazioni warm-up (backoffice).
abstract final class WarmupContestationAdminService {
  static final _firestore = FirebaseFirestore.instance;

  static Future<void> _requireAdmin() async {
    if (!await BkAdminService.isAdmin(forceRefresh: true)) {
      throw StateError('Accesso riservato agli amministratori.');
    }
  }

  static String _autoTitle(String declared) {
    final text = declared.trim();
    if (text.length <= 48) return text;
    return '${text.substring(0, 45)}…';
  }

  static Future<WarmupContestation> ensureSheets(WarmupContestation item) async {
    if (WarmupContestationService.hasCompleteSheets(item)) return item;
    await _requireAdmin();

    final generated = await WarmupContestationService.generateSheets(
      declared: item.declared,
      context: item.context,
    );

    await _firestore
        .collection(WarmupContestationService.collection)
        .doc(item.id)
        .update({
      'meaning': generated.meaning,
      'risk': generated.risk,
      'objective': generated.objective,
      'response': generated.response,
      'category': generated.category.name,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    return WarmupContestation(
      id: item.id,
      authorUid: item.authorUid,
      authorName: item.authorName,
      context: item.context,
      status: item.status,
      title: item.title,
      declared: item.declared,
      meaning: generated.meaning,
      risk: generated.risk,
      objective: generated.objective,
      response: generated.response,
      userRawInput: item.userRawInput,
      category: generated.category,
      rejectionNote: item.rejectionNote,
      reviewedAt: item.reviewedAt,
      reviewedBy: item.reviewedBy,
      createdAt: item.createdAt,
      updatedAt: item.updatedAt,
    );
  }

  static Future<String> save({
    String? id,
    required WarmupContestationContext context,
    required String declared,
    required WarmupContestationStatus status,
  }) async {
    await _requireAdmin();

    final user = FirebaseAuth.instance.currentUser;
    final uid = user?.uid;
    if (uid == null) throw StateError('Sessione scaduta.');

    final trimmedDeclared = declared.trim();
    if (trimmedDeclared.isEmpty) {
      throw StateError('La contestazione dichiarata è obbligatoria.');
    }

    final title = _autoTitle(trimmedDeclared);
    final generated = await WarmupContestationService.generateSheets(
      declared: trimmedDeclared,
      context: context,
    );

    if (id == null) {
      final ref = await _firestore
          .collection(WarmupContestationService.collection)
          .add({
        'authorUid': uid,
        if (user?.displayName?.trim().isNotEmpty == true)
          'authorName': user!.displayName!.trim(),
        'context': context.firestoreValue,
        'status': status.firestoreValue,
        'title': title,
        'declared': trimmedDeclared,
        'meaning': generated.meaning,
        'risk': generated.risk,
        'objective': generated.objective,
        'response': generated.response,
        'userRawInput': trimmedDeclared,
        'category': generated.category.name,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return ref.id;
    }

    final snap = await _firestore
        .collection(WarmupContestationService.collection)
        .doc(id)
        .get();
    if (!snap.exists) throw StateError('Contestazione non trovata.');

    await _firestore
        .collection(WarmupContestationService.collection)
        .doc(id)
        .update({
      'context': context.firestoreValue,
      'status': status.firestoreValue,
      'title': title,
      'declared': trimmedDeclared,
      'meaning': generated.meaning,
      'risk': generated.risk,
      'objective': generated.objective,
      'response': generated.response,
      'userRawInput': trimmedDeclared,
      'category': generated.category.name,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return id;
  }

  static Future<void> approve(String id) async {
    await _requireAdmin();
    await _firestore
        .collection(WarmupContestationService.collection)
        .doc(id)
        .update({
      'status': WarmupContestationStatus.approved.firestoreValue,
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
    await _requireAdmin();
    await _firestore
        .collection(WarmupContestationService.collection)
        .doc(id)
        .update({
      'status': WarmupContestationStatus.rejected.firestoreValue,
      'rejectionNote': (note ?? '').trim().isEmpty ? null : note!.trim(),
      'reviewedAt': FieldValue.serverTimestamp(),
      'reviewedBy': 'admin',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> delete(String id) async {
    await _requireAdmin();
    await _firestore
        .collection(WarmupContestationService.collection)
        .doc(id)
        .delete();
  }
}
