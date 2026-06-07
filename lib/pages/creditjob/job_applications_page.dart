// ignore_for_file: deprecated_member_use
// ================================================================
// IMPORT
// ================================================================

import 'package:flutter/material.dart';
import 'personal_job_shell.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';


// ================================================================
// PAGE
// ================================================================
class JobApplicationsPage extends StatelessWidget {
  final String jobId;
  final String jobTitle;

  const JobApplicationsPage({
    super.key,
    required this.jobId,
    required this.jobTitle,
  });

  // ================================================================
  // BUILD
  // ================================================================
  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return PersonalJobShell(
      pageTitle: 'Candidature – $jobTitle',
      body: user == null
          ? const Center(child: Text('Utente non autenticato'))
          : FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get(),
        builder: (context, userSnap) {
          if (userSnap.connectionState ==
              ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator());
          }

          if (!userSnap.hasData || !userSnap.data!.exists) {
            return const Center(
                child: Text('Dati azienda non trovati'));
          }

          final userData =
          userSnap.data!.data() as Map<String, dynamic>;

          final companyId =
              userData['companyId'] ?? user.uid;

          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('job_applications')
                .where('jobId', isEqualTo: jobId)
                .where('companyId', isEqualTo: companyId)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState ==
                  ConnectionState.waiting) {
                return const Center(
                    child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return const Center(
                  child: Text(
                    'Errore nel caricamento delle candidature',
                    style: TextStyle(color: Colors.red),
                  ),
                );
              }

              final docs = snapshot.data?.docs ?? [];

              if (docs.isEmpty) {
                return const Center(
                  child: Text('Nessuna candidatura ricevuta'),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: docs.length,
                itemBuilder: (context, index) {

                  final doc = docs[index];
                  final data =
                  doc.data() as Map<String, dynamic>;

                  // necessario per aggiornare lo stato
                  data['id'] = doc.id;

                  return Card(
                    margin:
                    const EdgeInsets.only(bottom: 12),
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius:
                      BorderRadius.circular(12),
                    ),
                    child: ListTile(
                      title: Text(
                        data['userName'] ?? 'Candidato',
                        style: const TextStyle(
                            fontWeight:
                            FontWeight.bold),
                      ),
                      subtitle: Column(
                        crossAxisAlignment:
                        CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text(data['userEmail'] ?? ''),
                          const SizedBox(height: 4),
                          Text(
                            'Candidatura: ${_formatDate(data['createdAt'])}',
                            style: const TextStyle(
                                fontSize: 12),
                          ),
                        ],
                      ),
                      trailing:
                      _statusChip(data['status']),
                      onTap: () {
                        _showDetailsDialog(
                            context, data);
                      },
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  // ================================================================
  // UI HELPERS
  // ================================================================
  static String _formatDate(dynamic value) {
    if (value is Timestamp) {
      final d = value.toDate();
      return '${d.day}/${d.month}/${d.year}';
    }
    return '';
  }

  Widget _statusChip(String? status) {
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
      case 'interview':
        return const Chip(
          label: Text('Colloquio'),
          backgroundColor: Colors.blue,
        );
      case 'hired':
        return const Chip(
          label: Text('Assunto'),
          backgroundColor: Colors.green,
        );
      default:
        return const Chip(
          label: Text('In valutazione'),
          backgroundColor: Colors.orange,
        );
    }
  }

  void _updateStatus(BuildContext context, Map<String, dynamic> data, String status) async {
    final id = data['id'] ?? data['applicationId'] ?? data['docId'];
    if (id == null) return;

    await FirebaseFirestore.instance
        .collection('job_applications')
        .doc(id)
        .update({'status': status});

    if (context.mounted) {
      Navigator.pop(context);
    }
  }

  void _showDetailsDialog(
      BuildContext context,
      Map<String, dynamic> data) {

    final cvUrl = data['cvUrl'];

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Dettaglio candidatura'),
        content: SizedBox(
          width: 480,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                _kv('Nome', data['userName']),
                _kv('Email', data['userEmail']),
                _kv('Presentazione', data['presentation']),

                const SizedBox(height: 16),

                if (cvUrl != null && cvUrl.toString().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: ElevatedButton.icon(
                      onPressed: () {
                        final url = cvUrl.toString();
                        launchUrl(
                          Uri.parse(url),
                          mode: LaunchMode.externalApplication,
                        );
                      },
                      icon: const Icon(Icons.download),
                      label: const Text('Apri CV'),
                    ),
                  ),

                const SizedBox(height: 12),

                Row(
                  children: [

                    ElevatedButton(
                      onPressed: () {
                        _updateStatus(context, data, 'interview');
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                      ),
                      child: const Text('Colloquio'),
                    ),

                    const SizedBox(width: 8),

                    ElevatedButton(
                      onPressed: () {
                        _updateStatus(context, data, 'rejected');
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                      ),
                      child: const Text('Scarta'),
                    ),

                    const SizedBox(width: 8),

                    ElevatedButton(
                      onPressed: () {
                        _updateStatus(context, data, 'hired');
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                      ),
                      child: const Text('Assumi'),
                    ),

                  ],
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.pop(context),
            child: const Text('Chiudi'),
          ),
        ],
      ),
    );
  }

  Widget _kv(String label, String? value) {
    if (value == null || value.trim().isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13)),
          const SizedBox(height: 2),
          Text(value),
        ],
      ),
    );
  }
}