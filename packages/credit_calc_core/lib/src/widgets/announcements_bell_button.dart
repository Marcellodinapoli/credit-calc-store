import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../pages/announcements_page.dart';

/// Campanella notifiche con badge non lette (come CreditPlanet).
class AnnouncementsBellButton extends StatelessWidget {
  final Color iconColor;
  final double iconSize;

  const AnnouncementsBellButton({
    super.key,
    this.iconColor = Colors.white70,
    this.iconSize = 20,
  });

  void _openAnnouncements(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const AnnouncementsPage(),
      ),
    );
  }

  int _unreadCount({
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> announcements,
    required Set<String> seenIds,
    required String userType,
  }) {
    return announcements
        .where((doc) {
          final data = doc.data();
          final target = data['target'] ?? 'all';
          return target == 'all' || target == userType;
        })
        .where((doc) => !seenIds.contains(doc.id))
        .length;
  }

  Widget _bellButton(BuildContext context, {required int unread}) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          key: const ValueKey('announcements_bell_button'),
          tooltip: 'Notifiche',
          onPressed: () => _openAnnouncements(context),
          icon: Icon(Icons.notifications, color: iconColor, size: iconSize),
        ),
        if (unread > 0)
          Positioned(
            right: 6,
            top: 6,
            child: IgnorePointer(
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                constraints: const BoxConstraints(
                  minWidth: 16,
                  minHeight: 16,
                ),
                child: Text(
                  unread > 9 ? '9+' : unread.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return _bellButton(context, unread: 0);
    }

    final announcementsStream = FirebaseFirestore.instance
        .collection('announcements')
        .where('active', isEqualTo: true)
        .snapshots();

    final userStream =
        FirebaseFirestore.instance.collection('users').doc(uid).snapshots();

    final seenStream = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('seen_announcements')
        .snapshots();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: announcementsStream,
      builder: (context, announcementsSnap) {
        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: userStream,
          builder: (context, userSnap) {
            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: seenStream,
              builder: (context, seenSnap) {
                final userType =
                    (userSnap.data?.data()?['type'] ?? 'public').toString();
                final announcements = announcementsSnap.data?.docs ?? [];
                final seenIds =
                    seenSnap.data?.docs.map((e) => e.id).toSet() ?? {};
                final unread = _unreadCount(
                  announcements: announcements,
                  seenIds: seenIds,
                  userType: userType,
                );
                return _bellButton(context, unread: unread);
              },
            );
          },
        );
      },
    );
  }
}
