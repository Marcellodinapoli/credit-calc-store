import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'local_notifications_service.dart';
import 'product_notifications_service.dart';
import 'push_platform.dart';

/// Su Windows FCM non è disponibile: ascolta gli annunci Firestore e mostra toast.
class DesktopPushService {
  DesktopPushService._();

  static final _firestore = FirebaseFirestore.instance;
  static StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
      _announcementsSub;
  static String? _uid;
  static String? _userType;
  static bool _baselineReady = false;
  static final Set<String> _seenIds = {};

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
    if (_uid == uid && _announcementsSub != null) return;

    await stop();
    _uid = uid;
    _baselineReady = false;
    _seenIds.clear();

    final userDoc = await _firestore.collection('users').doc(uid).get();
    _userType = (userDoc.data()?['type'] ?? 'all').toString();

    _announcementsSub = _firestore
        .collection('announcements')
        .where('active', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .listen(
      _onAnnouncements,
      onError: (Object error) {
        if (kDebugMode) {
          debugPrint('Desktop push announcements: $error');
        }
      },
    );
  }

  static Future<void> stop() async {
    await _announcementsSub?.cancel();
    _announcementsSub = null;
    _uid = null;
    _userType = null;
    _baselineReady = false;
    _seenIds.clear();
  }

  static void _onAnnouncements(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    if (_uid == null) return;

    if (!_baselineReady) {
      for (final doc in snapshot.docs) {
        _seenIds.add(doc.id);
      }
      _baselineReady = true;
      return;
    }

    for (final change in snapshot.docChanges) {
      if (change.type == DocumentChangeType.removed) continue;
      _handleAnnouncement(change.doc);
    }
  }

  static Future<void> _handleAnnouncement(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    if (_seenIds.contains(doc.id)) return;

    final data = doc.data();
    if (data == null) return;
    if (data['active'] == false) return;

    final target = (data['target'] ?? 'all').toString();
    final userType = _userType ?? 'all';
    if (target != 'all' && target != userType) {
      _seenIds.add(doc.id);
      return;
    }

    _seenIds.add(doc.id);

    final title = (data['title'] ?? 'CreditCore').toString();
    final message = (data['message'] ?? '').toString();
    final body = message.length > 240
        ? '${message.substring(0, 237)}...'
        : (message.isEmpty ? 'Nuovo aggiornamento disponibile' : message);

    await LocalNotificationsService.showProductNotification(
      title: title,
      body: body,
      payload: doc.id,
    );
  }
}
