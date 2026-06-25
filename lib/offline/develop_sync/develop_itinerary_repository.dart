import '../../models/field_activity.dart';
import '../../models/field_reminder.dart';
import '../../models/field_visit.dart';
import '../../utils/field_activity_sort.dart';
import 'develop_sync_sqlite_store.dart';
import 'models/develop_local_collection.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DevelopItineraryRepository {
  DevelopItineraryRepository(this._store);

  final DevelopSyncSqliteStore _store;

  String get userId => _store.userId;

  Stream<List<FieldVisit>> watchVisits() {
    return _store
        .watchRevision(DevelopLocalCollection.fieldVisits)
        .asyncMap((_) => listVisits());
  }

  Future<List<FieldVisit>> listVisits() async {
    final rows =
        await _store.recordsForCollection(DevelopLocalCollection.fieldVisits);
    return rows.map((row) => FieldVisit.fromMap(row.id, row.payload)).toList();
  }

  Future<FieldVisit?> getVisit(String id) async {
    final row = await _store.recordById(
      collection: DevelopLocalCollection.fieldVisits,
      id: id,
    );
    if (row == null) return null;
    return FieldVisit.fromMap(row.id, row.payload);
  }

  Future<String> saveVisit({
    String? id,
    required FieldVisit visit,
    bool isNew = false,
    Map<String, dynamic> extra = const {},
  }) async {
    final recordId = (id != null && id.isNotEmpty)
        ? id
        : DateTime.now().microsecondsSinceEpoch.toString();
    var payload = visit.copyWith(id: recordId, userId: userId).toStoredMap();
    if (!isNew) {
      final existing = await getVisit(recordId);
      if (existing != null) {
        payload = {
          ...existing.toStoredMap(),
          ...visit.toStoredMap(),
          'userId': userId,
        };
      }
    }
    payload.addAll(extra);
    if (isNew || payload['createdAt'] == null) {
      payload['createdAt'] = Timestamp.fromDate(DateTime.now());
    }

    await _store.upsertRecord(
      collection: DevelopLocalCollection.fieldVisits,
      id: recordId,
      payload: payload,
      createdAt: isNew ? DateTime.now() : null,
    );
    return recordId;
  }

  Future<void> deleteVisit(String id) async {
    await _store.deleteRecord(
      collection: DevelopLocalCollection.fieldVisits,
      id: id,
    );
  }

  Stream<List<FieldActivity>> watchActivities() {
    return _store
        .watchRevision(DevelopLocalCollection.fieldActivities)
        .asyncMap((_) => listActivities());
  }

  Future<List<FieldActivity>> listActivities() async {
    final rows = await _store.recordsForCollection(
      DevelopLocalCollection.fieldActivities,
    );
    return sortFieldActivities(
      rows.map((row) => FieldActivity.fromMap(row.id, row.payload)).toList(),
    );
  }

  Future<String> saveActivity({
    String? id,
    required FieldActivity activity,
    bool isNew = false,
  }) async {
    final recordId = (id != null && id.isNotEmpty)
        ? id
        : DateTime.now().microsecondsSinceEpoch.toString();
    var payload =
        activity.copyWith(id: recordId, userId: userId).toStoredMap();
    if (!isNew) {
      final row = await _store.recordById(
        collection: DevelopLocalCollection.fieldActivities,
        id: recordId,
      );
      if (row != null) {
        payload = {
          ...FieldActivity.fromMap(recordId, row.payload).toStoredMap(),
          ...payload,
          'userId': userId,
        };
      }
    }
    if (isNew || payload['createdAt'] == null) {
      payload['createdAt'] = Timestamp.fromDate(DateTime.now());
    }

    await _store.upsertRecord(
      collection: DevelopLocalCollection.fieldActivities,
      id: recordId,
      payload: payload,
      createdAt: isNew ? DateTime.now() : null,
    );
    return recordId;
  }

  Future<void> deleteActivity(String id) async {
    await _store.deleteRecord(
      collection: DevelopLocalCollection.fieldActivities,
      id: id,
    );
  }

  Stream<List<FieldReminder>> watchReminders() {
    return _store
        .watchRevision(DevelopLocalCollection.fieldReminders)
        .asyncMap((_) => listReminders());
  }

  Future<List<FieldReminder>> listReminders() async {
    final rows = await _store.recordsForCollection(
      DevelopLocalCollection.fieldReminders,
    );
    final items =
        rows.map((row) => FieldReminder.fromMap(row.id, row.payload)).toList();
    items.sort((a, b) => a.remindAt.compareTo(b.remindAt));
    return items;
  }

  Future<String> saveReminder({
    String? id,
    required FieldReminder reminder,
    bool isNew = false,
    bool resetPushSent = false,
  }) async {
    final recordId = (id != null && id.isNotEmpty)
        ? id
        : DateTime.now().microsecondsSinceEpoch.toString();
    var payload = reminder
        .copyWith(id: recordId, userId: userId)
        .toStoredMap(resetPushSent: resetPushSent);
    if (!isNew) {
      final row = await _store.recordById(
        collection: DevelopLocalCollection.fieldReminders,
        id: recordId,
      );
      if (row != null) {
        payload = {
          ...FieldReminder.fromMap(recordId, row.payload).toStoredMap(),
          ...payload,
          'userId': userId,
        };
      }
    }
    if (isNew || payload['createdAt'] == null) {
      payload['createdAt'] = Timestamp.fromDate(DateTime.now());
      payload['pushSent'] ??= false;
    }

    await _store.upsertRecord(
      collection: DevelopLocalCollection.fieldReminders,
      id: recordId,
      payload: payload,
      createdAt: isNew ? DateTime.now() : null,
    );
    return recordId;
  }

  Future<void> deleteReminder(String id) async {
    await _store.deleteRecord(
      collection: DevelopLocalCollection.fieldReminders,
      id: id,
    );
  }
}

extension FieldVisitCopy on FieldVisit {
  FieldVisit copyWith({
    String? id,
    String? userId,
    String? companyName,
    String? address,
    DateTime? scheduledAt,
    FieldVisitStatus? status,
    double? latitude,
    double? longitude,
    String? creditorId,
    String? creditorName,
    String? calculationId,
    String? notes,
    int? routeOrder,
  }) {
    return FieldVisit(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      companyName: companyName ?? this.companyName,
      address: address ?? this.address,
      scheduledAt: scheduledAt ?? this.scheduledAt,
      status: status ?? this.status,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      creditorId: creditorId ?? this.creditorId,
      creditorName: creditorName ?? this.creditorName,
      calculationId: calculationId ?? this.calculationId,
      notes: notes ?? this.notes,
      routeOrder: routeOrder ?? this.routeOrder,
    );
  }
}

extension FieldActivityCopy on FieldActivity {
  FieldActivity copyWith({
    String? id,
    String? userId,
    String? title,
    bool? completed,
    String? notes,
    DateTime? dueAt,
    String? visitId,
    int? recurrenceDays,
  }) {
    return FieldActivity(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      completed: completed ?? this.completed,
      notes: notes ?? this.notes,
      dueAt: dueAt ?? this.dueAt,
      visitId: visitId ?? this.visitId,
      recurrenceDays: recurrenceDays ?? this.recurrenceDays,
    );
  }
}

extension FieldReminderCopy on FieldReminder {
  FieldReminder copyWith({
    String? id,
    String? userId,
    String? title,
    DateTime? remindAt,
    String? notes,
    String? visitId,
    bool? pushSent,
  }) {
    return FieldReminder(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      remindAt: remindAt ?? this.remindAt,
      notes: notes ?? this.notes,
      visitId: visitId ?? this.visitId,
      pushSent: pushSent ?? this.pushSent,
    );
  }
}
