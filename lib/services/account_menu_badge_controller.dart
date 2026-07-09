import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'account_menu_badge_notifier.dart';

/// Ascolta Firestore + readState utente e aggiorna i badge del menù account.
final class AccountMenuBadgeController {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  StreamSubscription<User?>? _authSub;
  final _subs = <StreamSubscription<dynamic>>[];
  final _messageSubs = <String, StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>{};
  final _notifier = AccountMenuBadgeNotifier.instance;

  int _supportLastSeenMs = 0;
  int _communityMenuLastSeenMs = 0;
  int _roleplayLastSeenMs = 0;
  int _coursesLastSeenMs = 0;
  int _warmupLastSeenMs = 0;
  int _jobOffersLastSeenMs = 0;

  QuerySnapshot<Map<String, dynamic>>? _supportTickets;
  final Map<String, QuerySnapshot<Map<String, dynamic>>> _supportMessages = {};
  QuerySnapshot<Map<String, dynamic>>? _communityTopics;
  final Map<String, QuerySnapshot<Map<String, dynamic>>> _communityMessages = {};
  QuerySnapshot<Map<String, dynamic>>? _courses;
  QuerySnapshot<Map<String, dynamic>>? _roleplay;
  QuerySnapshot<Map<String, dynamic>>? _jobOffers;
  QuerySnapshot<Map<String, dynamic>>? _warmupApproved;

  Timer? _recomputeTimer;
  String? _uid;

  void start() {
    if (_authSub != null) return;

    _authSub = _auth.authStateChanges().listen((user) {
      if (user == null) {
        _stopDataListeners();
        _notifier.badges.value = const AccountMenuBadges();
        return;
      }
      if (_uid == user.uid) return;
      _stopDataListeners();
      _uid = user.uid;
      _attachListeners(user.uid);
    });
  }

  void stop() {
    unawaited(_authSub?.cancel());
    _authSub = null;
    _stopDataListeners();
    _notifier.badges.value = const AccountMenuBadges();
  }

  void _stopDataListeners() {
    _recomputeTimer?.cancel();
    _recomputeTimer = null;
    for (final sub in _subs) {
      unawaited(sub.cancel());
    }
    _subs.clear();
    for (final sub in _messageSubs.values) {
      unawaited(sub.cancel());
    }
    _messageSubs.clear();
    _uid = null;
    _supportTickets = null;
    _supportMessages.clear();
    _communityTopics = null;
    _communityMessages.clear();
    _courses = null;
    _roleplay = null;
    _jobOffers = null;
    _warmupApproved = null;
  }

  void _attachListeners(String uid) {
    _subs.add(
      _firestore.collection('users').doc(uid).snapshots().listen((snap) {
        _applyReadState(snap.data()?['readState']);
        _scheduleRecompute();
      }),
    );

    _subs.add(
      _firestore
          .collection('support')
          .where('userId', isEqualTo: uid)
          .snapshots()
          .listen((snap) {
        _supportTickets = snap;
        _syncChildListeners(
          currentIds: snap.docs.map((doc) => doc.id).toSet(),
          prefix: 'support:',
          attach: (ticketId) {
            _messageSubs['support:$ticketId'] = _firestore
                .collection('support')
                .doc(ticketId)
                .collection('messages')
                .snapshots()
                .listen((messages) {
              _supportMessages[ticketId] = messages;
              _scheduleRecompute();
            });
          },
          onRemove: (ticketId) => _supportMessages.remove(ticketId),
        );
        _scheduleRecompute();
      }),
    );

    _subs.add(
      _firestore
          .collection('community')
          .where('status', isEqualTo: 'approved')
          .snapshots()
          .listen((snap) {
        _communityTopics = snap;
        _syncChildListeners(
          currentIds: snap.docs.map((doc) => doc.id).toSet(),
          prefix: 'community:',
          attach: (topicId) {
            _messageSubs['community:$topicId'] = _firestore
                .collection('community')
                .doc(topicId)
                .collection('messages')
                .snapshots()
                .listen((messages) {
              _communityMessages[topicId] = messages;
              _scheduleRecompute();
            });
          },
          onRemove: (topicId) => _communityMessages.remove(topicId),
        );
        _scheduleRecompute();
      }),
    );

    _subs.add(
      _firestore.collection('courses').snapshots().listen((snap) {
        _courses = snap;
        _scheduleRecompute();
      }),
    );

    _subs.add(
      _firestore.collection('roleplay').snapshots().listen((snap) {
        _roleplay = snap;
        _scheduleRecompute();
      }),
    );

    _subs.add(
      _firestore
          .collection('job_offers')
          .where('status', isEqualTo: 'approved')
          .where('online', isEqualTo: true)
          .snapshots()
          .listen((snap) {
        _jobOffers = snap;
        _scheduleRecompute();
      }),
    );

    _subs.add(
      _firestore
          .collection('warmup_contestations')
          .where('status', isEqualTo: 'approved')
          .snapshots()
          .listen((snap) {
        _warmupApproved = snap;
        _scheduleRecompute();
      }),
    );
  }

  void _syncChildListeners({
    required Set<String> currentIds,
    required String prefix,
    required void Function(String id) attach,
    required void Function(String id) onRemove,
  }) {
    final stale = _messageSubs.keys
        .where((key) => key.startsWith(prefix) && !currentIds.contains(key.substring(prefix.length)))
        .toList();
    for (final key in stale) {
      unawaited(_messageSubs.remove(key)?.cancel());
      onRemove(key.substring(prefix.length));
    }

    for (final id in currentIds) {
      final key = '$prefix$id';
      if (_messageSubs.containsKey(key)) continue;
      attach(id);
    }
  }

  void _applyReadState(dynamic raw) {
    final state = raw is Map<String, dynamic>
        ? raw
        : raw is Map
            ? Map<String, dynamic>.from(raw)
            : const <String, dynamic>{};

    _supportLastSeenMs = _asInt(state['supportLastSeenMs']);
    _communityMenuLastSeenMs = _asInt(state['communityMenuLastSeenMs']);
    _roleplayLastSeenMs = _asInt(state['roleplayLastSeenMs']);
    _coursesLastSeenMs = _asInt(state['coursesLastSeenMs']);
    _warmupLastSeenMs = _asInt(state['warmupLastSeenMs']);
    _jobOffersLastSeenMs = _asInt(state['jobOffersLastSeenMs']);
  }

  void _scheduleRecompute() {
    _recomputeTimer?.cancel();
    _recomputeTimer = Timer(const Duration(milliseconds: 120), _recompute);
  }

  void _recompute() {
    final uid = _uid;
    if (uid == null) {
      _notifier.badges.value = const AccountMenuBadges();
      return;
    }

    _notifier.badges.value = AccountMenuBadges(
      directSupport: _hasSupportUnread(),
      community: _hasCommunityUnread(uid),
      courses: _hasCoursesUnread(),
      warmup: _hasWarmupUnread(uid),
      roleplay: _hasRoleplayUnread(),
      jobOffers: _hasJobOffersUnread(),
    );
  }

  bool _hasSupportUnread() {
    if (_supportLastSeenMs <= 0) return false;
    for (final messages in _supportMessages.values) {
      for (final doc in messages.docs) {
        final data = doc.data();
        if (data['sender'] == 'user') continue;
        final ts = data['timestamp'];
        if (ts is Timestamp && ts.millisecondsSinceEpoch > _supportLastSeenMs) {
          return true;
        }
      }
    }
    return false;
  }

  bool _hasCommunityUnread(String uid) {
    if (_communityMenuLastSeenMs <= 0) return false;
    for (final messages in _communityMessages.values) {
      for (final doc in messages.docs) {
        final data = doc.data();
        if ((data['userId'] ?? '').toString() == uid) continue;
        final ts = data['timestamp'];
        if (ts is Timestamp &&
            ts.millisecondsSinceEpoch > _communityMenuLastSeenMs) {
          return true;
        }
      }
    }
    return false;
  }

  bool _hasCoursesUnread() {
    if (_coursesLastSeenMs <= 0) return false;
    for (final doc in _courses?.docs ?? const []) {
      final createdAt = doc.data()['createdAt'];
      if (createdAt is Timestamp &&
          createdAt.millisecondsSinceEpoch > _coursesLastSeenMs) {
        return true;
      }
    }
    return false;
  }

  bool _hasWarmupUnread(String uid) {
    if (_warmupLastSeenMs <= 0) return false;
    for (final doc in _warmupApproved?.docs ?? const []) {
      final data = doc.data();
      if ((data['authorUid'] ?? '').toString() == uid) continue;
      final millis = _docMillis(data['updatedAt']) ?? _docMillis(data['createdAt']);
      if (millis != null && millis > _warmupLastSeenMs) return true;
    }
    return false;
  }

  bool _hasRoleplayUnread() {
    if (_roleplayLastSeenMs <= 0) return false;
    for (final doc in _roleplay?.docs ?? const []) {
      final millis = _docMillis(doc.data()['date']);
      if (millis != null && millis > _roleplayLastSeenMs) return true;
    }
    return false;
  }

  bool _hasJobOffersUnread() {
    if (_jobOffersLastSeenMs <= 0) return false;
    for (final doc in _jobOffers?.docs ?? const []) {
      final createdAt = doc.data()['createdAt'];
      if (createdAt is Timestamp &&
          createdAt.millisecondsSinceEpoch > _jobOffersLastSeenMs) {
        return true;
      }
    }
    return false;
  }

  int? _docMillis(dynamic raw) {
    if (raw is Timestamp) return raw.millisecondsSinceEpoch;
    if (raw is String) return DateTime.tryParse(raw)?.millisecondsSinceEpoch;
    return null;
  }

  int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.round();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}
