import 'package:flutter/material.dart';
import 'personal_job_shell.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../job/job_models.dart';
import '../../job/job_repository.dart';
import '../../services/read_state_service.dart';
import '../../core/theme/app_card_theme.dart';
import 'job_detail_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';

class JobOffersPage extends StatefulWidget {
  final JobRepository repo;
  final Set<String> saved;
  final Set<String> applied;
  final void Function(String id) onToggleSave;
  final void Function(String id) onApply;

  const JobOffersPage({
    super.key,
    required this.repo,
    required this.saved,
    required this.applied,
    required this.onToggleSave,
    required this.onApply,
  });

  @override
  State<JobOffersPage> createState() => _JobOffersPageState();
}

class _JobOffersPageState extends State<JobOffersPage> {

  // ---------------------------------------------------------------------------
  // STATE
  // ---------------------------------------------------------------------------

  final String _selectedLocation = 'Tutte le sedi';
  WorkMode? _modeFilter;
  String _query = '';
  int _lastSeen = 0;
  bool _readStateReady = false;

// 🔹 Saved Jobs realtime
  Set<String> _savedJobs = {};
  StreamSubscription<QuerySnapshot>? _savedSubscription;
  // ---------------------------------------------------------------------------
// LIFECYCLE
// ---------------------------------------------------------------------------

  @override
  void initState() {
    super.initState();
    _initReadState();
    _listenSavedJobs();
  }

  Future<void> _initReadState() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    _lastSeen = await ReadStateService.getJobOffersLastSeenMs();

    if (_lastSeen == 0) {
      await ReadStateService.ensureJobOffersInitialized(now);
      _lastSeen = now;
    } else {
      await ReadStateService.setJobOffersLastSeenMs(now);
    }

    if (!mounted) return;
    setState(() => _readStateReady = true);
  }

  void _listenSavedJobs() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _savedSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('saved_jobs')
        .snapshots()
        .listen((snapshot) {
      final ids = snapshot.docs.map((d) => d.id).toSet();

      setState(() {
        _savedJobs = ids;
      });
    });
  }

  @override
  void dispose() {
    _savedSubscription?.cancel();
    super.dispose();
  }

// ---------------------------------------------------------------------------
// BUILD
// ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return PersonalJobShell(
      pageTitle: 'Offerte di lavoro',
      body: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                _buildSearch(),

                const SizedBox(height: 16),

                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('job_offers')
                        .where('status', isEqualTo: 'approved')
                        .where('online', isEqualTo: true)
                        .snapshots(),
                    builder: (context, snapshot) {

                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (snapshot.hasError) {
                        return Center(
                          child: Text(
                            "Errore nel caricamento offerte\n${snapshot.error}",
                            style: const TextStyle(color: Colors.red),
                          ),
                        );
                      }

                      final docs = snapshot.data?.docs ?? [];

                      if (docs.isEmpty) {
                        return const Center(
                          child: Text('Nessuna offerta trovata'),
                        );
                      }

                      final validDocs = docs.toList();

                      final List<JobOffer> offers =
                      _mapDocsToOffers(validDocs);

                      final now = DateTime.now();

                      final activeOffers = offers.where((o) {
                        if (o.expiryDate == null) return true;
                        return o.expiryDate!.isAfter(now);
                      }).toList();

                      final filtered =
                      _applyLocalFilters(activeOffers);

                      return ListView.builder(
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {

                          final offer = filtered[index];

                          final doc =
                          validDocs.firstWhere((d) => d.id == offer.id);

                          final data =
                          doc.data() as Map<String, dynamic>;

                          final createdTs =
                          data['createdAt'] as Timestamp?;
                          final createdDate =
                          createdTs?.toDate();

                          DateTime? expiryDate;
                          final rawExpiry = data['expiryDate'];

                          if (rawExpiry is Timestamp) {
                            expiryDate = rawExpiry.toDate().toLocal();
                          } else if (rawExpiry is String) {
                            expiryDate = DateTime.tryParse(rawExpiry)?.toLocal();
                          }

                          final millis =
                          createdTs != null
                              ? createdTs.millisecondsSinceEpoch
                              : 0;

                          final isNew =
                              _readStateReady && millis > _lastSeen;
                          final isSaved = _savedJobs.contains(offer.id);

                          String statusLabel = "Attiva";
                          Color statusColor = Colors.green;

                          bool isExpired = false;

                          if (expiryDate != null) {
                            final now = DateTime.now();

                            if (expiryDate.isBefore(now)) {
                              statusLabel = "Scaduta";
                              statusColor = Colors.red;
                              isExpired = true;
                            } else if (expiryDate
                                .difference(now)
                                .inDays <= 7) {
                              statusLabel = "In scadenza";
                              statusColor = Colors.orange;
                            }
                          }

                          String formatDate(DateTime? d) {
                            if (d == null) return "-";
                            return "${d.day.toString().padLeft(2, '0')}/"
                                "${d.month.toString().padLeft(2, '0')}/"
                                "${d.year}";
                          }

                          return Card(
                            color: AppCardTheme.surface,
                            elevation: AppCardTheme.elevation,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment:
                                CrossAxisAlignment.start,
                                children: [

                                  Row(
                                    mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                    children: [

                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                          children: [

                                            Text(
                                              offer.title,
                                              style: const TextStyle(
                                                fontSize: 18,
                                                fontWeight:
                                                FontWeight.bold,
                                              ),
                                            ),

                                            const SizedBox(height: 4),

                                            Text(
                                              offer.company,
                                              style: const TextStyle(
                                                fontSize: 14,
                                                fontWeight:
                                                FontWeight.w500,
                                                color: Colors.black87,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),

                                      IconButton(
                                        icon: Icon(
                                          isSaved
                                              ? Icons.favorite
                                              : Icons.favorite_border,
                                          color: isSaved
                                              ? Colors.red
                                              : Colors.grey,
                                        ),
                                        onPressed: () async {
                                          await _toggleSaveJob(offer.id);
                                        },
                                      ),

                                      if (isNew)
                                        Container(
                                          margin:
                                          const EdgeInsets.only(right: 8),
                                          padding:
                                          const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 4),
                                          decoration:
                                          BoxDecoration(
                                            color: Colors.redAccent,
                                            borderRadius:
                                            BorderRadius.circular(12),
                                          ),
                                          child: const Text(
                                            'NEW',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontWeight:
                                              FontWeight.bold,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),

                                      Container(
                                        padding:
                                        const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 4),
                                        decoration: BoxDecoration(
                                          color: statusColor,
                                          borderRadius:
                                          BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          statusLabel,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight:
                                            FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),

                                  const SizedBox(height: 8),

                                  Text(
                                    "Città: ${offer.location}",
                                    style: const TextStyle(
                                        color: Colors.black87,
                                        fontWeight:
                                        FontWeight.w500),
                                  ),

                                  const SizedBox(height: 8),

                                  Text(
                                    "Inserita il: ${formatDate(createdDate)}",
                                    style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.black54),
                                  ),

                                  Text(
                                    "Scadenza: ${formatDate(expiryDate)}",
                                    style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.black54),
                                  ),

                                  const SizedBox(height: 12),

                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: user == null
                                        ? const SizedBox.shrink()
                                        : StreamBuilder<QuerySnapshot>(
                                      stream: FirebaseFirestore
                                          .instance
                                          .collection(
                                          'job_applications')
                                          .where('userId',
                                          isEqualTo:
                                          user.uid)
                                          .where('jobId',
                                          isEqualTo:
                                          offer.id)
                                          .limit(1)
                                          .snapshots(),
                                      builder:
                                          (context, snap) {

                                        final hasApplied =
                                            snap.hasData &&
                                                snap.data!
                                                    .docs
                                                    .isNotEmpty;

                                        final canView =
                                            !isExpired ||
                                                isSaved ||
                                                hasApplied;

                                        return Row(
                                          mainAxisSize:
                                          MainAxisSize.min,
                                          children: [

                                            if (hasApplied)
                                              Container(
                                                margin:
                                                const EdgeInsets.only(
                                                    right:
                                                    12),
                                                padding:
                                                const EdgeInsets.symmetric(
                                                    horizontal:
                                                    12,
                                                    vertical:
                                                    6),
                                                decoration:
                                                BoxDecoration(
                                                  color: Colors
                                                      .green
                                                      .shade50,
                                                  borderRadius:
                                                  BorderRadius
                                                      .circular(
                                                      20),
                                                  border: Border.all(
                                                      color:
                                                      Colors
                                                          .green),
                                                ),
                                                child:
                                                const Text(
                                                  "Candidatura inviata",
                                                  style:
                                                  TextStyle(
                                                    color:
                                                    Colors
                                                        .green,
                                                    fontWeight:
                                                    FontWeight
                                                        .w600,
                                                  ),
                                                ),
                                              ),

                                            ElevatedButton(
                                              onPressed: canView
                                                  ? () {
                                                Navigator.of(
                                                    context)
                                                    .push(
                                                  MaterialPageRoute(
                                                    builder:
                                                        (_) =>
                                                        JobDetailPage(
                                                          offer:
                                                          offer,
                                                          repo: widget
                                                              .repo,
                                                          saved:
                                                          isSaved,
                                                          applied:
                                                          hasApplied,
                                                          onToggleSave:
                                                              () =>
                                                              _toggleSaveJob(
                                                                  offer.id),
                                                          onApply:
                                                              () {},
                                                        ),
                                                  ),
                                                );
                                              }
                                                  : null,
                                              child: Text(
                                                canView
                                                    ? "Visualizza"
                                                    : "Offerta scaduta",
                                              ),
                                            ),
                                          ],
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
  // ---------------------------------------------------------------------------
  // UI HELPERS
  // ---------------------------------------------------------------------------

  Widget _buildSearch() {
    return TextField(
      decoration: InputDecoration(
        prefixIcon: const Icon(Icons.search),
        hintText: 'Cerca per ruolo, azienda o sede',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        isDense: true,
      ),
      onChanged: (v) => setState(() => _query = v),
    );
  }
  // ---------------------------------------------------------------------------
// SERVICES / ACTIONS
// ---------------------------------------------------------------------------

  Future<void> _toggleSaveJob(String jobId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final docRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('saved_jobs')
          .doc(jobId);

      final doc = await docRef.get();

      if (doc.exists) {
        // 🔹 Rimuovi dai preferiti
        await docRef.delete();
      } else {
        // 🔹 Aggiungi ai preferiti
        await docRef.set({
          'jobId': jobId,
          'savedAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      debugPrint('Errore toggle save job: $e');
    }
  }
// ---------------------------------------------------------------------------
// SERVICES / HELPERS
// ---------------------------------------------------------------------------

  List<JobOffer> _mapDocsToOffers(
      List<QueryDocumentSnapshot> docs) {

    return docs.map<JobOffer>((doc) {

      final data =
      doc.data() as Map<String, dynamic>;

      return JobOffer.fromFirestore(
        doc.id,
        data,
      );

    }).toList();
  }
// ---------------------------------------------------------------------------
// LOGIC
// ---------------------------------------------------------------------------

  List<JobOffer> _applyLocalFilters(List<JobOffer> offers) {
    final now = DateTime.now();

    return offers.where((o) {

      // 🔥 FILTRO SCADENZA (lista principale)
      if (o.expiryDate != null && o.expiryDate!.isBefore(now)) {
        return false;
      }

      if (_selectedLocation != 'Tutte le sedi' &&
          o.location != _selectedLocation) {
        return false;
      }

      if (_modeFilter != null &&
          o.mode != _modeFilter) {
        return false;
      }

      if (_query.isNotEmpty) {
        final q = _query.toLowerCase();
        if (!o.title.toLowerCase().contains(q) &&
            !o.company.toLowerCase().contains(q) &&
            !o.location.toLowerCase().contains(q)) {
          return false;
        }
      }

      return true;
    }).toList();
  }
}