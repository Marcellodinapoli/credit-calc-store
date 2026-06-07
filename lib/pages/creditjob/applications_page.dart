// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'personal_job_shell.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../job/job_repository.dart';
import '../../core/theme/app_card_theme.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../job/job_models.dart';
import 'job_detail_page.dart';

class ApplicationsPage extends StatefulWidget {
  final JobRepository repo;
  final Set<String> applied;
  final Set<String> saved;
  final void Function(String id) onWithdraw; // ✅ RIPRISTINATO

  const ApplicationsPage({
    super.key,
    required this.repo,
    required this.applied,
    required this.saved,
    required this.onWithdraw, // ✅ RIPRISTINATO
  });

  @override
  State<ApplicationsPage> createState() => _ApplicationsPageState();
}

class _ApplicationsPageState extends State<ApplicationsPage> {

// ---------------------------------------------------------------------------
// ACTIONS
// ---------------------------------------------------------------------------

// ---------------------------------------------------------------------------
// BUILD
// ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const SizedBox.shrink();
    }

    return PersonalJobShell(
      pageTitle: 'Le mie candidature',
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('job_applications')
            .where('userId', isEqualTo: user.uid)
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return const Center(
              child: Text('Errore caricamento candidature'),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text('Non hai ancora inviato candidature'),
            );
          }

          final docs = snapshot.data!.docs;

          return ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              itemCount: docs.length,
              itemBuilder: (_, i) {

                final data =
                docs[i].data() as Map<String, dynamic>;

                final applicationId = docs[i].id;
                final jobId =
                    data['jobId'] as String? ?? '';
                final jobTitle =
                    data['jobTitle'] as String? ?? '';
                final companyName =
                    data['companyName'] as String? ?? '';
                final status =
                    data['status'] as String? ?? 'pending';
                final createdAt =
                data['createdAt'] as Timestamp?;
                final cvUrl =
                data['cvUrl'] as String?;

                Color statusColor;
                String statusLabel;

                switch (status) {
                  case 'approved':
                    statusColor = Colors.green;
                    statusLabel = 'Accettata';
                    break;
                  case 'rejected':
                    statusColor = Colors.red;
                    statusLabel = 'Rifiutata';
                    break;
                  case 'reviewed':
                    statusColor = Colors.orange;
                    statusLabel = 'In valutazione';
                    break;
                  default:
                    statusColor = Colors.blueGrey;
                    statusLabel = 'Inviata';
                }

                String formatDate(DateTime? d) {
                  if (d == null) return "-";
                  return "${d.day.toString().padLeft(2, '0')}/"
                      "${d.month.toString().padLeft(2, '0')}/"
                      "${d.year}";
                }

                return InkWell(
                  onTap: () async {
                    if (jobId.isEmpty) return;

                    final doc = await FirebaseFirestore.instance
                        .collection('job_offers')
                        .doc(jobId)
                        .get();

                    if (!doc.exists) return;

                    final offer = JobOffer.fromFirestore(
                      doc.id,
                      doc.data() as Map<String, dynamic>,
                    );

                    if (!context.mounted) return;

                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => JobDetailPage(
                          offer: offer,
                          repo: widget.repo,
                          saved: widget.saved.contains(offer.id),
                          applied: true,
                          onToggleSave: () {},
                          onApply: () {},
                        ),
                      ),
                    );
                  },
                  child: Card(
                    color: AppCardTheme.surface,
                    elevation: AppCardTheme.elevation,
                    shape: RoundedRectangleBorder(
                      borderRadius:
                      BorderRadius.circular(14),
                    ),
                    child: Padding(
                      padding:
                      const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment:
                        CrossAxisAlignment.start,
                        children: [

                          Row(
                            mainAxisAlignment:
                            MainAxisAlignment
                                .spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                  CrossAxisAlignment
                                      .start,
                                  children: [
                                    Text(
                                      jobTitle,
                                      style:
                                      const TextStyle(
                                        fontSize: 16,
                                        fontWeight:
                                        FontWeight
                                            .bold,
                                      ),
                                    ),
                                    const SizedBox(
                                        height: 4),
                                    Text(
                                      companyName,
                                      style:
                                      const TextStyle(
                                        color: Colors
                                            .black87,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              Container(
                                padding:
                                const EdgeInsets
                                    .symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration:
                                BoxDecoration(
                                  color: statusColor
                                      .withValues(
                                      alpha: 0.15),
                                  borderRadius:
                                  BorderRadius
                                      .circular(
                                      20),
                                  border: Border.all(
                                      color:
                                      statusColor),
                                ),
                                child: Text(
                                  statusLabel,
                                  style: TextStyle(
                                    color:
                                    statusColor,
                                    fontWeight:
                                    FontWeight
                                        .w600,
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 8),

                          Text(
                            "Inviata il: ${formatDate(createdAt?.toDate())}",
                            style:
                            const TextStyle(
                              fontSize: 12,
                              color:
                              Colors.black54,
                            ),
                          ),

                          const SizedBox(height: 12),

                          Row(
                            mainAxisAlignment:
                            MainAxisAlignment
                                .end,
                            children: [

                              if (cvUrl != null &&
                                  cvUrl.isNotEmpty)
                                TextButton.icon(
                                  icon: const Icon(
                                      Icons.download),
                                  label: const Text(
                                      "Scarica CV"),
                                  onPressed: () {
                                    launchUrl(
                                      Uri.parse(cvUrl),
                                      mode: LaunchMode.externalApplication,
                                    );
                                  },
                                ),

                              if (cvUrl != null &&
                                  cvUrl.isNotEmpty)
                                const SizedBox(width: 8),

                              if (cvUrl != null &&
                                  cvUrl.isNotEmpty)
                                TextButton.icon(
                                  icon: const Icon(
                                      Icons.delete_outline),
                                  label: const Text(
                                      "Elimina CV"),
                                  onPressed: () async {

                                    final confirm =
                                    await showDialog<bool>(
                                      context: context,
                                      builder: (_) =>
                                          AlertDialog(
                                            title: const Text(
                                                'Elimina allegato'),
                                            content: const Text(
                                                'Sei sicuro di voler eliminare il CV allegato?'),
                                            actions: [
                                              TextButton(
                                                onPressed: () =>
                                                    Navigator.pop(
                                                        context,
                                                        false),
                                                child: const Text(
                                                    'Annulla'),
                                              ),
                                              TextButton(
                                                onPressed: () =>
                                                    Navigator.pop(
                                                        context,
                                                        true),
                                                child: const Text(
                                                  'Elimina',
                                                  style: TextStyle(
                                                      color: Colors
                                                          .red),
                                                ),
                                              ),
                                            ],
                                          ),
                                    );

                                    if (confirm != true) {
                                      return;
                                    }

                                    try {

                                      try {
                                        await FirebaseStorage
                                            .instance
                                            .refFromURL(
                                            cvUrl)
                                            .delete();
                                      } catch (_) {}

                                      await FirebaseFirestore
                                          .instance
                                          .collection(
                                          'job_applications')
                                          .doc(
                                          applicationId)
                                          .update({
                                        'cvUrl':
                                        FieldValue
                                            .delete(),
                                        'cvFileName':
                                        FieldValue
                                            .delete(),
                                      });

                                      setState(() {});

                                    } catch (_) {}
                                  },
                                ),

                              const SizedBox(width: 8),

                              IconButton(
                                tooltip:
                                'Ritira candidatura',
                                icon: const Icon(
                                    Icons.undo),
                                onPressed: () async {

                                  final confirm =
                                  await showDialog<bool>(
                                    context: context,
                                    builder: (_) =>
                                        AlertDialog(
                                          title: const Text(
                                              'Ritira candidatura'),
                                          content: const Text(
                                              'Sei sicuro di voler ritirare questa candidatura?'),
                                          actions: [
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(
                                                      context,
                                                      false),
                                              child: const Text(
                                                  'Annulla'),
                                            ),
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(
                                                      context,
                                                      true),
                                              child: const Text(
                                                'Ritira',
                                                style: TextStyle(
                                                    color:
                                                    Colors
                                                        .red),
                                              ),
                                            ),
                                          ],
                                        ),
                                  );

                                  if (confirm != true) return;

                                  try {
                                    if (cvUrl != null &&
                                        cvUrl.isNotEmpty) {
                                      try {
                                        await FirebaseStorage
                                            .instance
                                            .refFromURL(
                                            cvUrl)
                                            .delete();
                                      } catch (_) {}
                                    }

                                    await FirebaseFirestore
                                        .instance
                                        .collection(
                                        'job_applications')
                                        .doc(
                                        applicationId)
                                        .delete();

                                    widget.onWithdraw(
                                        applicationId);

                                  } catch (_) {}
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
        },
      ),
    );
  }
}