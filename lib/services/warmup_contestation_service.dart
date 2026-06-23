import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/warmup_contestation.dart';

/// CRUD contestazioni warm-up inserite dagli utenti.
abstract final class WarmupContestationService {
  static const collection = 'warmup_contestations';

  static final _firestore = FirebaseFirestore.instance;

  static String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  static CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection(collection);

  /// Contestazioni approvate + proprie (qualsiasi stato) per contesto.
  static Stream<List<WarmupContestation>> watchForContext(
    WarmupContestationContext context,
  ) {
    final uid = _uid;
    if (uid == null) return Stream.value(const []);

    final ctx = context.firestoreValue;

    final approved$ = _col
        .where('context', isEqualTo: ctx)
        .where('status', isEqualTo: 'approved')
        .snapshots();

    final mine$ = _col
        .where('context', isEqualTo: ctx)
        .where('authorUid', isEqualTo: uid)
        .snapshots();

    return approved$.asyncExpand((approvedSnap) async* {
      await for (final mineSnap in mine$) {
        final byId = <String, WarmupContestation>{};
        for (final doc in approvedSnap.docs) {
          byId[doc.id] = WarmupContestation.fromDoc(doc);
        }
        for (final doc in mineSnap.docs) {
          byId[doc.id] = WarmupContestation.fromDoc(doc);
        }
        final list = byId.values.toList()
          ..sort((a, b) {
            final aMine = a.authorUid == uid;
            final bMine = b.authorUid == uid;
            if (aMine != bMine) return aMine ? -1 : 1;
            final at = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            final bt = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            return bt.compareTo(at);
          });
        yield list;
      }
    });
  }

  static Future<String> create({
    required WarmupContestationContext context,
    required String title,
    required String declared,
    required String meaning,
    required String risk,
    required String objective,
    required String response,
    String? userRawInput,
    WarmupContestationCategory category =
        WarmupContestationCategory.generica,
    required WarmupContestationStatus status,
    String? authorName,
  }) async {
    final uid = _uid;
    if (uid == null) {
      throw StateError('Sessione scaduta.');
    }

    final draft = WarmupContestation(
      id: '',
      authorUid: uid,
      authorName: authorName,
      context: context,
      status: status,
      title: title,
      declared: declared,
      meaning: meaning,
      risk: risk,
      objective: objective,
      response: response,
      userRawInput: userRawInput,
      category: category,
    );

    final ref = await _col.add(
      draft.toCreateMap(status: status),
    );
    return ref.id;
  }

  static Future<void> update({
    required String id,
    required String title,
    required String declared,
    required String meaning,
    required String risk,
    required String objective,
    required String response,
    String? userRawInput,
    WarmupContestationCategory category =
        WarmupContestationCategory.generica,
    required WarmupContestationStatus status,
  }) async {
    final uid = _uid;
    if (uid == null) throw StateError('Sessione scaduta.');

    final snap = await _col.doc(id).get();
    if (!snap.exists) throw StateError('Contestazione non trovata.');
    final existing = WarmupContestation.fromDoc(snap);
    if (existing.authorUid != uid) {
      throw StateError('Non puoi modificare questa contestazione.');
    }
    if (!existing.canEdit) {
      throw StateError('La contestazione è già condivisa e non è modificabile.');
    }

    final updated = WarmupContestation(
      id: id,
      authorUid: uid,
      authorName: existing.authorName,
      context: existing.context,
      status: status,
      title: title,
      declared: declared,
      meaning: meaning,
      risk: risk,
      objective: objective,
      response: response,
      userRawInput: userRawInput,
      category: category,
    );

    await _col.doc(id).update(updated.toUpdateMap(status: status));
  }

  static Future<void> delete(String id) async {
    final uid = _uid;
    if (uid == null) throw StateError('Sessione scaduta.');

    final snap = await _col.doc(id).get();
    if (!snap.exists) return;
    final existing = WarmupContestation.fromDoc(snap);
    if (existing.authorUid != uid) {
      throw StateError('Non puoi eliminare questa contestazione.');
    }
    if (!existing.canDelete) {
      throw StateError('La contestazione condivisa non può essere eliminata.');
    }
    await _col.doc(id).delete();
  }

  /// In attesa di moderazione BK.
  static Stream<List<WarmupContestation>> watchPendingReview() {
    return _col
        .where('status', isEqualTo: 'pending_review')
        .snapshots()
        .map(
          (snap) => snap.docs
              .map(WarmupContestation.fromDoc)
              .toList()
            ..sort((a, b) {
              final at = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
              final bt = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
              return bt.compareTo(at);
            }),
        );
  }
}
