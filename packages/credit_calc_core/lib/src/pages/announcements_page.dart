import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../layout/credit_calc_page_host.dart';
import '../nav/credit_calc_nav.dart';

/// Elenco annunci / notifiche (stessa logica di CreditPlanet).
class AnnouncementsPage extends StatefulWidget {
  const AnnouncementsPage({super.key});

  @override
  State<AnnouncementsPage> createState() => _AnnouncementsPageState();
}

class _AnnouncementsPageState extends State<AnnouncementsPage> {
  final Set<String> _expanded = {};

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _filterAnnouncements(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    String userType,
  ) {
    return docs.where((doc) {
      final data = doc.data();
      final target = data['target'] ?? 'all';
      return target == 'all' || target == userType;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return wrapCreditCalcPage(
      secondary: true,
      pageTitle: 'Notifiche',
      current: CreditCalcNavItem.creditors,
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('announcements')
            .where('active', isEqualTo: true)
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, announcementsSnap) {
          if (announcementsSnap.connectionState == ConnectionState.waiting &&
              !announcementsSnap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = announcementsSnap.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(child: Text('Nessuna notifica'));
          }

          if (uid == null) {
            return _announcementsList(
              docs: docs,
              seenIds: const {},
            );
          }

          return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(uid)
                .snapshots(),
            builder: (context, userSnap) {
              final userType =
                  (userSnap.data?.data()?['type'] ?? 'public').toString();
              final filteredDocs = _filterAnnouncements(docs, userType);

              if (filteredDocs.isEmpty) {
                return const Center(child: Text('Nessuna notifica'));
              }

              return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(uid)
                    .collection('seen_announcements')
                    .snapshots(),
                builder: (context, seenSnap) {
                  final seenIds =
                      seenSnap.data?.docs.map((e) => e.id).toSet() ?? {};
                  return _announcementsList(
                    docs: filteredDocs,
                    seenIds: seenIds,
                    uid: uid,
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _announcementsList({
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    required Set<String> seenIds,
    String? uid,
  }) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: docs.length,
      itemBuilder: (context, index) {
        final doc = docs[index];
        final data = doc.data();

        final title = data['title'] ?? '';
        final message = data['message'] ?? '';
        final type = data['type'] ?? 'avviso';
        final createdAt = data['createdAt'] as Timestamp?;

        final isExpanded = _expanded.contains(doc.id);
        final isRead = seenIds.contains(doc.id);

        final dateText = createdAt != null
            ? _formatDate(createdAt.toDate())
            : '';

        return Card(
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      type == 'alert'
                          ? Icons.warning
                          : type == 'aggiornamento'
                              ? Icons.system_update
                              : Icons.campaign,
                      color: Colors.blue,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        title.toString(),
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight:
                              isRead ? FontWeight.normal : FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  dateText,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.black54,
                  ),
                ),
                const SizedBox(height: 12),
                if (isExpanded)
                  Text(
                    message.toString(),
                    style: const TextStyle(fontSize: 14),
                  ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () async {
                      if (!_expanded.contains(doc.id)) {
                        setState(() {
                          _expanded.add(doc.id);
                        });

                        if (uid != null) {
                          await FirebaseFirestore.instance
                              .collection('users')
                              .doc(uid)
                              .collection('seen_announcements')
                              .doc(doc.id)
                              .set({
                            'seenAt': Timestamp.now(),
                          });
                        }
                      }
                    },
                    child: Text(
                      isExpanded ? 'Aperto' : 'Apri',
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year} '
        '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
  }
}
