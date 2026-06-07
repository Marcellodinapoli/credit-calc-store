// ================================================================
// IMPORT
// ================================================================

import 'package:flutter/material.dart';
import 'personal_job_shell.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../job/job_models.dart';
import '../../job/job_repository.dart';
import '../../core/theme/app_card_theme.dart';
import 'job_widgets.dart';
import 'job_detail_page.dart';

// ================================================================
// PAGE
// ================================================================

class SavedPage extends StatelessWidget {
  final JobRepository repo;
  final Set<String> saved; // compatibilità
  final Set<String> applied;
  final void Function(String id) onToggleSave; // compatibilità

  const SavedPage({
    super.key,
    required this.repo,
    required this.saved,
    required this.applied,
    required this.onToggleSave,
  });

// ================================================================
// BUILD
// ================================================================

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const PersonalJobShell(
      pageTitle: 'Salvati',
        body: Center(
          child: Text("Utente non autenticato"),
        ),
      );
    }

    return PersonalJobShell(
      pageTitle: 'Salvati',
      body: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .collection('saved_jobs')
                .orderBy('savedAt', descending: true)
                .snapshots(),
            builder: (context, savedSnapshot) {
              if (savedSnapshot.connectionState ==
                  ConnectionState.waiting) {
                return const Center(
                    child: CircularProgressIndicator());
              }

              if (!savedSnapshot.hasData ||
                  savedSnapshot.data!.docs.isEmpty) {
                return const Center(
                    child: Text('Nessuna offerta salvata'));
              }

              final savedIds =
              savedSnapshot.data!.docs.map((d) => d.id).toList();

              return FutureBuilder<QuerySnapshot>(
                future: FirebaseFirestore.instance
                    .collection('job_offers')
                    .where(FieldPath.documentId, whereIn: savedIds)
                    .get(),
                builder: (context, offersSnapshot) {
                  if (offersSnapshot.connectionState ==
                      ConnectionState.waiting) {
                    return const Center(
                        child: CircularProgressIndicator());
                  }

                  if (!offersSnapshot.hasData ||
                      offersSnapshot.data!.docs.isEmpty) {
                    return const Center(
                        child: Text('Nessuna offerta trovata'));
                  }

                  final offers = offersSnapshot.data!.docs
                      .map((doc) {
                    final data =
                    doc.data() as Map<String, dynamic>;
                    return JobOffer.fromFirestore(
                        doc.id, data);
                  })
                      .toList()
                    ..sort((a, b) =>
                        b.date.compareTo(a.date));

                  return ListView.builder(
                    padding:
                    const EdgeInsets.fromLTRB(12, 8, 12, 12),
                    itemCount: offers.length,
                    itemBuilder: (_, i) {
                      final o = offers[i];
                      final appliedFlag =
                      applied.contains(o.id);

                      final now = DateTime.now();
                      final isExpired =
                          o.expiryDate != null &&
                              o.expiryDate!.isBefore(now);

                      String statusLabel = "";
                      Color statusColor = Colors.green;

                      if (isExpired) {
                        statusLabel = "Scaduta";
                        statusColor = Colors.red;
                      } else if (o.expiryDate != null &&
                          o.expiryDate!
                              .difference(now)
                              .inDays <=
                              7) {
                        statusLabel = "In scadenza";
                        statusColor = Colors.orange;
                      }

                      return Card(
                        color: AppCardTheme.surface,
                        elevation: AppCardTheme.elevation,
                        child: ListTile(
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  o.title,
                                  style: const TextStyle(
                                      fontWeight:
                                      FontWeight.w700),
                                ),
                              ),
                              if (statusLabel.isNotEmpty)
                                Container(
                                  padding:
                                  const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2),
                                  decoration: BoxDecoration(
                                    color: statusColor,
                                    borderRadius:
                                    BorderRadius.circular(
                                        12),
                                  ),
                                  child: Text(
                                    statusLabel,
                                    style:
                                    const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight:
                                      FontWeight.bold,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          subtitle: Row(
                            mainAxisSize:
                            MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.business_outlined,
                                size: 16,
                                color: Colors.black45,
                              ),
                              const SizedBox(width: 4),
                              Text(o.company),
                              const SizedBox(width: 8),
                              const Icon(
                                Icons.place,
                                size: 16,
                                color: Colors.black45,
                              ),
                              const SizedBox(width: 4),
                              Text(o.location),
                              if (appliedFlag) ...[
                                const SizedBox(width: 8),
                                const AppliedPill(),
                              ],
                            ],
                          ),
                          trailing: IconButton(
                            tooltip:
                            'Rimuovi dai preferiti',
                            icon:
                            const Icon(Icons.bookmark),
                            onPressed: () async {
                              await FirebaseFirestore
                                  .instance
                                  .collection('users')
                                  .doc(user.uid)
                                  .collection(
                                  'saved_jobs')
                                  .doc(o.id)
                                  .delete();
                            },
                          ),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  JobDetailPage(
                                    offer: o,
                                    repo: repo,
                                    saved: true,
                                    applied:
                                    appliedFlag,
                                    onToggleSave:
                                        () async {
                                      await FirebaseFirestore
                                          .instance
                                          .collection(
                                          'users')
                                          .doc(user.uid)
                                          .collection(
                                          'saved_jobs')
                                          .doc(o.id)
                                          .delete();
                                    },
                                    onApply: () {},
                                  ),
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
    );
  }}