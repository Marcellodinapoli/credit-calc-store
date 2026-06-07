// -----------------------------------------------------------------------------
// IMPORT
// -----------------------------------------------------------------------------
import 'package:flutter/material.dart';
import 'personal_job_shell.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'job_offer_preview_page.dart';
import 'job_applications_page.dart';
import 'create_job_offer_wizard_page.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

// -----------------------------------------------------------------------------
// PAGE ROOT
// -----------------------------------------------------------------------------
class GestioneLavoriPage extends StatelessWidget {
  const GestioneLavoriPage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return PersonalJobShell(
      pageTitle: 'Gestione lavori',
      body: user == null
          ? const Center(child: Text('Utente non autenticato'))
          : Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(context, user.uid),
          const SizedBox(height: 16),
          Expanded(child: _buildJobsTable(context, user.uid)),
        ],
      ),
    );
  }

// ---------------------------------------------------------------------------
// UI HELPERS
// ---------------------------------------------------------------------------

  Widget _buildHeader(BuildContext context, String companyId) {
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 12,
      runSpacing: 12,
      children: [
        const Text(
          'Le tue offerte di lavoro',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        ElevatedButton.icon(
          onPressed: () async {

            // 1️⃣ leggo regolamento dal BackOffice
            final rulesDoc = await FirebaseFirestore.instance
                .collection('settings')
                .doc('job_offer_rules')
                .get();

            if (!rulesDoc.exists) {
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                      'Regolamento non disponibile. Contattare l’amministratore.'),
                ),
              );
              return;
            }

            final rules = rulesDoc.data() as Map<String, dynamic>;

            final String version =
            (rules['version'] ?? '1.0').toString();

            final String title =
            (rules['title'] ?? 'Regole pubblicazione offerte')
                .toString();

            // 🔧 CORREZIONE: leggo il testo dalla versione corrente
            final versionDoc = await FirebaseFirestore.instance
                .collection('settings')
                .doc('job_offer_rules')
                .collection('versions')
                .doc(version)
                .get();

            final versionData =
            versionDoc.data();

            final String content =
            (versionData?['text'] ?? '').toString();

            // 2️⃣ leggo azienda
            final companyDoc = await FirebaseFirestore.instance
                .collection('companies')
                .doc(companyId)
                .get();

            bool alreadyAccepted = false;

            if (companyDoc.exists) {
              final data = companyDoc.data() as Map<String, dynamic>;
              final acceptedVersion =
              (data['rulesAcceptedVersion'] ?? '').toString();

              if (acceptedVersion == version) {
                alreadyAccepted = true;
              }
            }

            // SE GIÀ ACCETTATO → wizard
            if (alreadyAccepted) {
              if (!context.mounted) return;
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      CreateJobOfferWizardPage(companyId: companyId),
                ),
              );
              return;
            }

            // 3️⃣ popup regolamento
            if (!context.mounted) return;
            final accepted = await showDialog<bool>(
              context: context,
              barrierDismissible: false,
              builder: (dialogContext) {

                final scrollController = ScrollController();
                bool reachedEnd = false;
                bool checked = false;
                bool listenerAdded = false;

                return StatefulBuilder(
                  builder: (context, setState) {

                    if (!listenerAdded) {
                      scrollController.addListener(() {
                        if (scrollController.hasClients) {
                          final max = scrollController.position.maxScrollExtent;
                          final current = scrollController.position.pixels;

                          if (max <= 0 || current >= max - 10) {
                            if (!reachedEnd) {
                              setState(() {
                                reachedEnd = true;
                              });
                            }
                          }
                        }
                      });
                      listenerAdded = true;
                    }

                    return AlertDialog(
                      title: Text(title),
                      content: SizedBox(
                        width: 500,
                        height: 320,
                        child: Column(
                          children: [

                            Expanded(
                              child: SingleChildScrollView(
                                controller: scrollController,
                                child: MarkdownBody(
                                  data: content,
                                ),
                              ),
                            ),

                            const SizedBox(height: 12),

                            CheckboxListTile(
                              value: checked,
                              onChanged: reachedEnd
                                  ? (v) {
                                setState(() {
                                  checked = v ?? false;
                                });
                              }
                                  : null,
                              title: const Text(
                                  'Ho letto e accetto il regolamento'),
                            ),

                          ],
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(dialogContext, rootNavigator: true).pop(false),
                          child: const Text('Annulla'),
                        ),
                        ElevatedButton(
                          onPressed: checked
                              ? () async {

                            final firestore = FirebaseFirestore.instance;

                            // 🔹 SALVO STATO ATTUALE
                            await firestore
                                .collection('companies')
                                .doc(companyId)
                                .update({
                              'rulesAcceptedVersion': version,
                              'rulesAcceptedAt': FieldValue.serverTimestamp(),
                            });

                            // 🔹 SALVO STORICO (NUOVO)
                            await firestore
                                .collection('companies')
                                .doc(companyId)
                                .collection('rules_history')
                                .doc(version)
                                .set({
                              'version': version,
                              'acceptedAt': FieldValue.serverTimestamp(),
                            });

                            if (!dialogContext.mounted) return;
                            Navigator.of(dialogContext, rootNavigator: true).pop();

                            if (!context.mounted) return;
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    CreateJobOfferWizardPage(companyId: companyId),
                              ),
                            );
                          }
                              : null,
                          child: const Text('Continua'),
                        ),
                      ],
                    );
                  },
                );
              },
            );

            // ⚠️ NON PIÙ USATO (gestione spostata nel bottone Continua)
            if (accepted == true) {}
          },
          icon: const Icon(Icons.add),
          label: const Text('Crea offerta'),
        ),
      ],
    );
  }

  Widget _buildJobsTable(BuildContext context, String companyId) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('job_offers')
          .where('companyId', isEqualTo: companyId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text('Errore nel caricamento offerte'));
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data!.docs;

        if (docs.isEmpty) {
          return const Center(
            child: Text('Non hai ancora creato offerte di lavoro'),
          );
        }

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: const [
              DataColumn(label: Text('Titolo')),
              DataColumn(label: Text('Candidature')),
              DataColumn(label: Text('Creato')),
              DataColumn(label: Text('Scadenza')),
              DataColumn(label: Text('Stato')),
              DataColumn(label: Text('Azioni')),
            ],
            rows: docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;

              DateTime? created;
              if (data['createdAt'] is Timestamp) {
                created = (data['createdAt'] as Timestamp).toDate();
              }

              DateTime? expiry =
              created?.add(const Duration(days: 30));

              final now = DateTime.now();
              final isExpired =
                  expiry != null && now.isAfter(expiry);

              bool isNearExpiry = false;
              if (expiry != null) {
                final diff =
                    expiry.difference(DateTime.now()).inDays;
                if (diff <= 5 && diff >= 0) {
                  isNearExpiry = true;
                }
              }

              return DataRow(cells: [
                DataCell(Text(data['title'] ?? '')),

                DataCell(
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('job_applications')
                        .where('jobId',
                        isEqualTo: data['jobId'] ?? doc.id)
                        .snapshots(),
                    builder: (context, snap) {
                      if (!snap.hasData) {
                        return const Text('0');
                      }
                      return Text('${snap.data!.docs.length}');
                    },
                  ),
                ),

                DataCell(Text(_formatDate(data['createdAt']))),

                DataCell(
                  Text(
                    expiry != null
                        ? "${expiry.day}/${expiry.month}/${expiry.year}"
                        : "-",
                    style: TextStyle(
                      color: isExpired
                          ? Colors.grey
                          : isNearExpiry
                          ? Colors.red
                          : Colors.black,
                      fontWeight: isNearExpiry
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                ),

                DataCell(
                  isExpired
                      ? const Chip(
                    label: Text('Scaduta'),
                    backgroundColor: Colors.grey,
                  )
                      : _buildStatusChip(data['status']),
                ),

                DataCell(
                  PopupMenuButton<String>(
                    onSelected: (value) => _handleAction(
                        context, value, doc, data, companyId),
                    itemBuilder: (_) {
                      if (isExpired) {
                        return const [
                          PopupMenuItem(
                            value: 'republish',
                            child: Text('Ripubblica'),
                          ),
                          PopupMenuItem(
                            value: 'delete',
                            child: Text('Elimina'),
                          ),
                        ];
                      }

                      return const [
                        PopupMenuItem(
                          value: 'view',
                          child: Text('Visualizza offerta'),
                        ),
                        PopupMenuItem(
                          value: 'edit',
                          child: Text('Modifica offerta'),
                        ),
                        PopupMenuItem(
                          value: 'applications',
                          child: Text('Candidature'),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: Text('Elimina'),
                        ),
                      ];
                    },
                  ),
                ),
              ]);
            }).toList(),
          ),
        );
      },
    );
  }

  Widget _buildStatusChip(String? status) {
    switch (status) {
      case 'approved':
        return const Chip(
          label: Text('Approvata'),
          backgroundColor: Colors.green,
        );
      case 'rejected':
        return const Chip(
          label: Text('Rifiutata'),
          backgroundColor: Colors.red,
        );
      case 'draft':
        return const Chip(
          label: Text('Bozza'),
          backgroundColor: Colors.grey,
        );
      default:
        return const Chip(
          label: Text('In approvazione'),
          backgroundColor: Colors.orange,
        );
    }
  }
// ---------------------------------------------------------------------------
// ACTIONS
// ---------------------------------------------------------------------------

  Future<void> _handleAction(
      BuildContext context,
      String value,
      DocumentSnapshot doc,
      Map<String, dynamic> data,
      String companyId,
      ) async {

    if (value == 'view') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => JobOfferPreviewPage(jobId: doc.id),
        ),
      );
      return;
    }

    if (value == 'edit') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CreateJobOfferWizardPage(
            companyId: companyId,
            jobId: doc.id,
          ),
        ),
      );
      return;
    }

    if (value == 'applications') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => JobApplicationsPage(
            jobId: doc.id,
            jobTitle: data['title'] ?? '',
          ),
        ),
      );
      return;
    }

    if (value == 'republish') {
      await FirebaseFirestore.instance
          .collection('job_offers')
          .doc(doc.id)
          .update({
        'createdAt': FieldValue.serverTimestamp(),
        'applicationsCount': 0,
        'status': 'pending',
      });
      return;
    }

    if (value == 'delete') {
      final ok = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Conferma eliminazione'),
          content: const Text(
            'Vuoi eliminare definitivamente questa offerta?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annulla'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Elimina'),
            ),
          ],
        ),
      );

      if (ok == true) {
        await FirebaseFirestore.instance
            .collection('job_offers')
            .doc(doc.id)
            .delete();
      }
      return;
    }
  }

// ---------------------------------------------------------------------------
// HELPERS
// ---------------------------------------------------------------------------

  static String _formatDate(dynamic value) {
    if (value is Timestamp) {
      final d = value.toDate();
      return '${d.day}/${d.month}/${d.year}';
    }
    return '';
  }
}