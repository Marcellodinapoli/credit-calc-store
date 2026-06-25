import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:credit_calc_core/credit_calc_core.dart' hide FirestoreUserScope;
import 'package:firebase_auth/firebase_auth.dart';

import '../core/firestore_user_scope.dart';
import '../models/field_activity.dart';
import '../models/field_reminder.dart';
import '../models/field_visit.dart';
import '../utils/field_activity_sort.dart';
import 'itinerary_storage.dart';

class FirestoreItineraryStorage implements ItineraryStorage {
  CollectionReference<Map<String, dynamic>> get _visits =>
      FirebaseFirestore.instance.collection('field_visits');

  CollectionReference<Map<String, dynamic>> get _activities =>
      FirebaseFirestore.instance.collection('field_activities');

  CollectionReference<Map<String, dynamic>> get _reminders =>
      FirebaseFirestore.instance.collection('field_reminders');

  @override
  Stream<List<FieldVisit>> watchAllVisits() {
    MigratedDataFirestorePolicy.assertFirestoreAccessAllowed();
    return FirebaseAuth.instance.authStateChanges().asyncExpand((user) {
      if (user == null) return Stream.value(const <FieldVisit>[]);
      return _visits.where('userId', isEqualTo: user.uid).snapshots().map(
            (snap) => snap.docs.map(FieldVisit.fromDoc).toList(),
          );
    });
  }

  @override
  Future<List<FieldVisit>> fetchAllVisits() async {
    MigratedDataFirestorePolicy.assertFirestoreAccessAllowed();
    final userId = FirestoreUserScope.uid;
    if (userId == null) return const [];
    final snap = await _visits.where('userId', isEqualTo: userId).get();
    return snap.docs.map(FieldVisit.fromDoc).toList();
  }

  @override
  Future<String> saveVisit({
    String? id,
    required FieldVisit visit,
    bool isNew = false,
    bool includePreVisitPushReset = false,
  }) async {
    MigratedDataFirestorePolicy.assertWritesAllowed();
    final data = FirestoreUserScope.withOwner({
      ...visit.toFirestore(),
      if (isNew) 'createdAt': FieldValue.serverTimestamp(),
      if (includePreVisitPushReset) 'preVisitPushSent': false,
    });

    if (isNew || id == null || id.isEmpty) {
      final ref = await _visits.add(data);
      return ref.id;
    }

    await _visits.doc(id).set(data, SetOptions(merge: true));
    return id;
  }

  @override
  Future<void> deleteVisit(String id) {
    MigratedDataFirestorePolicy.assertWritesAllowed();
    return _visits.doc(id).delete();
  }

  @override
  Future<void> updateVisitStatus(String id, FieldVisitStatus status) {
    MigratedDataFirestorePolicy.assertWritesAllowed();
    return _visits.doc(id).update({
      'status': status.name,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> saveVisitRouteOrder(List<FieldVisit> ordered) async {
    MigratedDataFirestorePolicy.assertWritesAllowed();
    final batch = FirebaseFirestore.instance.batch();
    for (var i = 0; i < ordered.length; i++) {
      batch.update(_visits.doc(ordered[i].id), {
        'routeOrder': i,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }

  @override
  Stream<List<FieldActivity>> watchAllActivities() {
    MigratedDataFirestorePolicy.assertFirestoreAccessAllowed();
    final userId = FirestoreUserScope.uid;
    if (userId == null) return Stream.value(const []);

    return _activities.where('userId', isEqualTo: userId).snapshots().map((snap) {
      return sortFieldActivities(
        snap.docs.map(FieldActivity.fromDoc).toList(),
      );
    });
  }

  @override
  Future<String> saveActivity({
    String? id,
    required FieldActivity activity,
    bool isNew = false,
  }) async {
    MigratedDataFirestorePolicy.assertWritesAllowed();
    final data = FirestoreUserScope.withOwner({
      ...activity.toFirestore(),
      if (isNew) 'createdAt': FieldValue.serverTimestamp(),
    });

    if (isNew || id == null || id.isEmpty) {
      final ref = await _activities.add(data);
      return ref.id;
    }

    await _activities.doc(id).set(data, SetOptions(merge: true));
    return id;
  }

  @override
  Future<void> deleteActivity(String id) {
    MigratedDataFirestorePolicy.assertWritesAllowed();
    return _activities.doc(id).delete();
  }

  @override
  Stream<List<FieldReminder>> watchAllReminders() {
    MigratedDataFirestorePolicy.assertFirestoreAccessAllowed();
    final userId = FirestoreUserScope.uid;
    if (userId == null) return Stream.value(const []);

    return _reminders.where('userId', isEqualTo: userId).snapshots().map((snap) {
      final items = snap.docs.map(FieldReminder.fromDoc).toList();
      items.sort((a, b) => a.remindAt.compareTo(b.remindAt));
      return items;
    });
  }

  @override
  Future<List<FieldReminder>> fetchAllReminders() async {
    MigratedDataFirestorePolicy.assertFirestoreAccessAllowed();
    final userId = FirestoreUserScope.uid;
    if (userId == null) return const [];

    final snap = await _reminders.where('userId', isEqualTo: userId).get();
    final items = snap.docs.map(FieldReminder.fromDoc).toList();
    items.sort((a, b) => a.remindAt.compareTo(b.remindAt));
    return items;
  }

  @override
  Future<String> saveReminder({
    String? id,
    required FieldReminder reminder,
    bool isNew = false,
    bool resetPushSent = false,
  }) async {
    MigratedDataFirestorePolicy.assertWritesAllowed();
    final data = FirestoreUserScope.withOwner({
      ...reminder.toFirestore(resetPushSent: resetPushSent),
      if (isNew) 'createdAt': FieldValue.serverTimestamp(),
      if (isNew) 'pushSent': false,
    });

    if (isNew || id == null || id.isEmpty) {
      final ref = await _reminders.add(data);
      return ref.id;
    }

    await _reminders.doc(id).set(data, SetOptions(merge: true));
    return id;
  }

  @override
  Future<void> deleteReminder(String id) {
    MigratedDataFirestorePolicy.assertWritesAllowed();
    return _reminders.doc(id).delete();
  }
}

