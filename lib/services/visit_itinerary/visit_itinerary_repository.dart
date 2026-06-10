import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../models/visit_stop.dart';

class VisitItineraryRepository {
  VisitItineraryRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  static String todayKey([DateTime? date]) {
    final d = date ?? DateTime.now();
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  CollectionReference<Map<String, dynamic>>? _stopsRef(String dateKey) {
    final uid = _uid;
    if (uid == null) return null;
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('visit_itineraries')
        .doc(dateKey)
        .collection('stops');
  }

  DocumentReference<Map<String, dynamic>>? _dayRef(String dateKey) {
    final uid = _uid;
    if (uid == null) return null;
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('visit_itineraries')
        .doc(dateKey);
  }

  Stream<List<VisitStop>> watchTodayStops() {
    final dateKey = todayKey();
    final ref = _stopsRef(dateKey);
    if (ref == null) return Stream.value(const []);

    return ref.orderBy('sortOrder').snapshots().map((snap) {
      return snap.docs
          .map((doc) => VisitStop.fromMap(doc.id, doc.data()))
          .toList();
    });
  }

  Future<void> addStop({
    required String clientName,
    required String address,
  }) async {
    final dateKey = todayKey();
    final stopsRef = _stopsRef(dateKey);
    final dayRef = _dayRef(dateKey);
    if (stopsRef == null || dayRef == null) return;

    final existing = await stopsRef.orderBy('sortOrder', descending: true).limit(1).get();
    final nextOrder = existing.docs.isEmpty
        ? 0
        : ((existing.docs.first.data()['sortOrder'] as num?)?.toInt() ?? 0) + 1;

    final batch = _firestore.batch();
    batch.set(dayRef, {
      'dateKey': dateKey,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    batch.set(stopsRef.doc(), {
      'clientName': clientName.trim(),
      'address': address.trim(),
      'sortOrder': nextOrder,
      'visited': false,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
  }

  Future<void> updateStop(VisitStop stop) async {
    final ref = _stopsRef(todayKey())?.doc(stop.id);
    if (ref == null) return;
    await ref.set(stop.toMap(), SetOptions(merge: true));
  }

  Future<void> deleteStop(String stopId) async {
    final ref = _stopsRef(todayKey())?.doc(stopId);
    if (ref == null) return;
    await ref.delete();
  }

  Future<void> saveOptimizedOrder(List<VisitStop> ordered) async {
    final stopsRef = _stopsRef(todayKey());
    final dayRef = _dayRef(todayKey());
    if (stopsRef == null || dayRef == null) return;

    final batch = _firestore.batch();
    batch.set(dayRef, {
      'optimizedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    for (var i = 0; i < ordered.length; i++) {
      batch.set(
        stopsRef.doc(ordered[i].id),
        {
          'sortOrder': i,
          'latitude': ordered[i].latitude,
          'longitude': ordered[i].longitude,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    }
    await batch.commit();
  }
}
