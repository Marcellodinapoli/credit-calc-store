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

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return IconButton(
        tooltip: 'Notifiche',
        onPressed: () => _openAnnouncements(context),
        icon: Icon(Icons.notifications, color: iconColor, size: iconSize),
      );
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('announcements')
          .where('active', isEqualTo: true)
          .snapshots(),
      builder: (context, snapshot) {
        return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          future: FirebaseFirestore.instance.collection('users').doc(uid).get(),
          builder: (context, userSnap) {
            if (!userSnap.hasData) {
              return IconButton(
                tooltip: 'Notifiche',
                onPressed: () => _openAnnouncements(context),
                icon: Icon(Icons.notifications, color: iconColor, size: iconSize),
              );
            }

            final userType = userSnap.data?.data()?['type'] ?? 'public';
            final raw = snapshot.data?.docs ?? [];
            final announcements = raw.where((doc) {
              final data = doc.data();
              final target = data['target'] ?? 'all';
              return target == 'all' || target == userType;
            }).toList();

            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(uid)
                  .collection('seen_announcements')
                  .snapshots(),
              builder: (context, seenSnap) {
                final seenIds =
                    seenSnap.data?.docs.map((e) => e.id).toSet() ?? {};
                final unread = announcements
                    .where((doc) => !seenIds.contains(doc.id))
                    .length;

                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    IconButton(
                      tooltip: 'Notifiche',
                      onPressed: () => _openAnnouncements(context),
                      icon: Icon(
                        Icons.notifications,
                        color: iconColor,
                        size: iconSize,
                      ),
                    ),
                    if (unread > 0)
                      Positioned(
                        right: 6,
                        top: 6,
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
                  ],
                );
              },
            );
          },
        );
      },
    );
  }
}
