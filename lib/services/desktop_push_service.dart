import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:credit_calc_core/credit_calc_core.dart' show AnnouncementsTargeting;
import 'package:flutter/foundation.dart';

import 'local_notifications_service.dart';
import 'notification_navigation.dart';
import 'product_notifications_service.dart';
import 'push_platform.dart';

/// Su Windows FCM non è disponibile: replica le push prodotto ascoltando Firestore
/// e mostrando toast locali (stessi eventi delle Cloud Functions, app in esecuzione).
class DesktopPushService {
  DesktopPushService._();

  static final _firestore = FirebaseFirestore.instance;
  static final List<StreamSubscription<dynamic>> _subs = [];
  static final Map<String, StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>
      _messageSubs = {};
  static final Set<String> _seenKeys = {};
  static final Set<String> _baselineReady = {};

  static String? _uid;
  static String? _userType;

  static Future<void> syncForCurrentUser(String uid) async {
    if (!supportsDesktopLocalPush) return;

    final enabled = await ProductNotificationsService.loadEnabled(uid);
    if (enabled) {
      await start(uid);
    } else {
      await stop();
    }
  }

  static Future<void> start(String uid) async {
    if (!supportsDesktopLocalPush) return;
    if (_uid == uid && _subs.isNotEmpty) return;

    await stop();
    _uid = uid;

    final userDoc = await _firestore.collection('users').doc(uid).get();
    _userType = AnnouncementsTargeting.normalizeUserType(
      userDoc.data()?['type'],
    );

    // Annunci: come CF, `added` sulla query active==true (prima attivazione).
    _listenQuery(
      key: 'announcements',
      query: _firestore
          .collection('announcements')
          .where('active', isEqualTo: true)
          .orderBy('createdAt', descending: true)
          .limit(50),
      onDoc: _onAnnouncement,
      onlyAdded: true,
    );

    _listenQuery(
      key: 'courses',
      query: _firestore.collection('courses'),
      onDoc: (doc) => _notify(
        seenKey: 'courses:${doc.id}',
        type: 'course',
        id: doc.id,
        title: 'Nuovo corso su CreditForm',
        body: (doc.data()?['title'] ?? 'Nuovo corso').toString(),
      ),
      onlyAdded: true,
    );

    _listenQuery(
      key: 'roleplay',
      query: _firestore.collection('roleplay'),
      onDoc: (doc) {
        final data = doc.data() ?? {};
        final title =
            (data['title'] ?? data['name'] ?? 'Nuova simulazione roleplay')
                .toString();
        return _notify(
          seenKey: 'roleplay:${doc.id}',
          type: 'roleplay',
          id: doc.id,
          title: 'Nuovo Role Play',
          body: title,
        );
      },
      onlyAdded: true,
    );

    // Solo non-aziende (come loadJobSeekerTargets).
    if (_userType != 'company') {
      _listenQuery(
        key: 'job_offers',
        query: _firestore
            .collection('job_offers')
            .where('status', isEqualTo: 'approved')
            .where('online', isEqualTo: true),
        onDoc: (doc) => _notify(
          seenKey: 'job_offers:${doc.id}',
          type: 'job_offer',
          id: doc.id,
          title: 'Nuova offerta su CreditJob',
          body: (doc.data()?['title'] ?? 'Offerta di lavoro').toString(),
        ),
        // Query filtrata: `added` = appena pubblicata (approved+online).
        onlyAdded: true,
      );
    }

    _subs.add(
      _firestore
          .collection('support')
          .where('userId', isEqualTo: uid)
          .snapshots()
          .listen(
        (snap) {
          final titles = <String, String>{
            for (final d in snap.docs)
              d.id: (d.data()['subject'] ?? 'Assistenza diretta')
                  .toString()
                  .trim(),
          };
          _syncChildListeners(
            currentIds: snap.docs.map((d) => d.id).toSet(),
            prefix: 'support:',
            attach: (ticketId) => _attachSupportTicket(
              ticketId,
              titles[ticketId]?.isNotEmpty == true
                  ? titles[ticketId]!
                  : 'Assistenza diretta',
            ),
          );
        },
        onError: _onListenError,
      ),
    );

    _subs.add(
      _firestore
          .collection('community')
          .where('userId', isEqualTo: uid)
          .snapshots()
          .listen(
        (snap) {
          final titles = <String, String>{};
          final ownedApproved = <String>{};
          for (final d in snap.docs) {
            if (d.data()['status'] != 'approved') continue;
            ownedApproved.add(d.id);
            final t = (d.data()['title'] ?? 'Community').toString().trim();
            titles[d.id] = t.isEmpty ? 'Community' : t;
          }
          _syncChildListeners(
            currentIds: ownedApproved,
            prefix: 'community:',
            attach: (topicId) => _attachCommunityTopic(
              topicId,
              titles[topicId] ?? 'Community',
            ),
          );
        },
        onError: _onListenError,
      ),
    );
  }

  static Future<void> stop() async {
    for (final sub in _subs) {
      await sub.cancel();
    }
    _subs.clear();
    for (final sub in _messageSubs.values) {
      await sub.cancel();
    }
    _messageSubs.clear();
    _uid = null;
    _userType = null;
    _seenKeys.clear();
    _baselineReady.clear();
  }

  static void _listenQuery({
    required String key,
    required Query<Map<String, dynamic>> query,
    required Future<void> Function(DocumentSnapshot<Map<String, dynamic>> doc)
        onDoc,
    bool onlyAdded = false,
  }) {
    _subs.add(
      query.snapshots().listen(
        (snapshot) {
          if (!_baselineReady.contains(key)) {
            for (final doc in snapshot.docs) {
              _seenKeys.add('$key:${doc.id}');
            }
            _baselineReady.add(key);
            return;
          }

          for (final change in snapshot.docChanges) {
            if (change.type == DocumentChangeType.removed) continue;
            if (onlyAdded && change.type != DocumentChangeType.added) continue;
            unawaited(onDoc(change.doc));
          }
        },
        onError: _onListenError,
      ),
    );
  }

  static void _syncChildListeners({
    required Set<String> currentIds,
    required String prefix,
    required void Function(String id) attach,
  }) {
    final existing = _messageSubs.keys
        .where((k) => k.startsWith(prefix))
        .map((k) => k.substring(prefix.length))
        .toSet();

    for (final id in existing.difference(currentIds)) {
      unawaited(_messageSubs.remove('$prefix$id')?.cancel());
      _baselineReady.remove('$prefix$id');
    }

    for (final id in currentIds.difference(existing)) {
      attach(id);
    }
  }

  static void _attachSupportTicket(String ticketId, String subject) {
    final key = 'support:$ticketId';
    _messageSubs[key] = _firestore
        .collection('support')
        .doc(ticketId)
        .collection('messages')
        .snapshots()
        .listen(
      (snap) async {
        if (!_baselineReady.contains(key)) {
          for (final doc in snap.docs) {
            _seenKeys.add('$key:${doc.id}');
          }
          _baselineReady.add(key);
          return;
        }

        for (final change in snap.docChanges) {
          if (change.type != DocumentChangeType.added) continue;
          final doc = change.doc;
          final seen = '$key:${doc.id}';
          if (_seenKeys.contains(seen)) continue;

          final data = doc.data() ?? <String, dynamic>{};
          final sender = (data['sender'] ?? '').toString();
          if (sender == 'user') {
            _seenKeys.add(seen);
            continue;
          }

          final text = (data['text'] ?? '').toString().trim();
          final body = text.isEmpty
              ? 'Nuovo messaggio di supporto'
              : (text.length > 160 ? '${text.substring(0, 157)}...' : text);

          await _notify(
            seenKey: seen,
            type: 'support_reply',
            id: ticketId,
            title: subject,
            body: body,
          );
        }
      },
      onError: _onListenError,
    );
  }

  static void _attachCommunityTopic(String topicId, String topicTitle) {
    final key = 'community:$topicId';
    final uid = _uid;
    _messageSubs[key] = _firestore
        .collection('community')
        .doc(topicId)
        .collection('messages')
        .snapshots()
        .listen(
      (snap) async {
        if (!_baselineReady.contains(key)) {
          for (final doc in snap.docs) {
            _seenKeys.add('$key:${doc.id}');
          }
          _baselineReady.add(key);
          return;
        }

        for (final change in snap.docChanges) {
          if (change.type != DocumentChangeType.added) continue;
          final doc = change.doc;
          final seen = '$key:${doc.id}';
          if (_seenKeys.contains(seen)) continue;

          final data = doc.data() ?? <String, dynamic>{};
          final senderId = (data['userId'] ?? '').toString().trim();
          if (senderId.isEmpty || senderId == uid) {
            _seenKeys.add(seen);
            continue;
          }

          final text =
              (data['text'] ?? data['message'] ?? '').toString().trim();
          final body = text.isEmpty
              ? 'Nuova risposta in community'
              : (text.length > 160 ? '${text.substring(0, 157)}...' : text);

          await _notify(
            seenKey: seen,
            type: 'community_message',
            id: topicId,
            title: topicTitle,
            body: body,
          );
        }
      },
      onError: _onListenError,
    );
  }

  static Future<void> _onAnnouncement(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    final data = doc.data();
    if (data == null) return;
    if (data['active'] == false) return;

    // Allineato alle CF: target "all" → solo utenti pubblici.
    final target = (data['target'] ?? 'all').toString();
    final userType = _userType ?? 'public';
    final matches = target == 'all'
        ? userType == 'public'
        : AnnouncementsTargeting.isVisibleForUser(
            data: data,
            userType: userType,
          );
    if (!matches) {
      _seenKeys.add('announcements:${doc.id}');
      return;
    }

    final title = (data['title'] ?? 'CreditCore').toString();
    final message = (data['message'] ?? '').toString();
    final body = message.length > 240
        ? '${message.substring(0, 237)}...'
        : (message.isEmpty ? 'Nuovo aggiornamento disponibile' : message);

    await _notify(
      seenKey: 'announcements:${doc.id}',
      type: 'announcement',
      id: doc.id,
      title: title,
      body: body,
    );
  }

  static Future<void> _notify({
    required String seenKey,
    required String type,
    required String id,
    required String title,
    required String body,
  }) async {
    if (_seenKeys.contains(seenKey)) return;
    _seenKeys.add(seenKey);

    await LocalNotificationsService.showProductNotification(
      title: title,
      body: body,
      payload: NotificationNavigation.encodeLocalPayload(type, id),
    );
  }

  static void _onListenError(Object error) {
    if (kDebugMode) {
      debugPrint('Desktop push: $error');
    }
    final message = error.toString();
    if (message.contains('permission-denied') ||
        message.contains('unauthenticated')) {
      unawaited(stop());
    }
  }
}
