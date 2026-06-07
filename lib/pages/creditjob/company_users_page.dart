import 'package:flutter/material.dart';
import 'personal_job_shell.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';


class CompanyUsersPage extends StatelessWidget {
  const CompanyUsersPage({super.key});

  @override
  Widget build(BuildContext context) {
    final companyUser = FirebaseAuth.instance.currentUser;

    if (companyUser == null) {
      return const Scaffold(
        body: Center(child: Text('Utente non autenticato')),
      );
    }

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('users')
          .doc(companyUser.uid)
          .get(),
      builder: (context, companySnap) {
        if (companySnap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!companySnap.hasData || !companySnap.data!.exists) {
          return const Center(child: Text('Dati azienda non disponibili'));
        }

        final companyData =
        companySnap.data!.data() as Map<String, dynamic>;
        final companyCode = companyData['userCode'];

        if (companyCode == null || companyCode.isEmpty) {
          return const Center(
            child: Text('Codice azienda non valido'),
          );
        }

        return PersonalJobShell(
      pageTitle: 'Utenti associati',
          body: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _infoBox(),
                const SizedBox(height: 16),
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('users')
                        .where('type', isEqualTo: 'work')
                        .where('companyCode', isEqualTo: companyCode)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState ==
                          ConnectionState.waiting) {
                        return const Center(
                          child: CircularProgressIndicator(),
                        );
                      }

                      if (snapshot.hasError) {
                        return const Center(
                          child: Text(
                            'Errore nel caricamento utenti',
                            style: TextStyle(color: Colors.red),
                          ),
                        );
                      }

                      final docs = snapshot.data?.docs ?? [];

                      if (docs.isEmpty) {
                        return const Center(
                          child: Text('Nessun collaboratore associato'),
                        );
                      }

                      final supervisors = docs.where((d) {
                        final data = d.data() as Map<String, dynamic>;
                        return data['workRole'] == 'supervisor';
                      }).toList();

                      final collaborators = docs.where((d) {
                        final data = d.data() as Map<String, dynamic>;
                        return data['workRole'] == 'collaborator';
                      }).toList();

                      return ListView(
                        children: [
                          if (supervisors.isNotEmpty) ...[
                            const Text(
                              'Supervisor',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            ...supervisors.map(
                                  (doc) => _userTile(doc),
                            ),
                          ],
                          if (supervisors.isNotEmpty &&
                              collaborators.isNotEmpty)
                            const Divider(height: 32),
                          if (collaborators.isNotEmpty) ...[
                            const Text(
                              'Collaboratori',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            ...collaborators.map(
                                  (doc) => _userTile(doc),
                            ),
                          ],
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
        );
      },
    );
  }

  Widget _userTile(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    final firstName = data['firstName'] ?? data['name'] ?? '';
    final lastName = data['lastName'] ?? data['surname'] ?? '';
    final email = data['email'] ?? '—';

    final fullName = ('$firstName $lastName').trim();
    final displayName = fullName.isNotEmpty ? fullName : '—';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(
          displayName,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(email),
      ),
    );
  }

  Widget _infoBox() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Row(
        children: [
          Icon(Icons.info_outline),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'In questo elenco sono visibili i supervisor e i collaboratori '
                  'associati all’azienda.',
              style: TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}

class CompanyUserDetailPage extends StatelessWidget {
  final String userId;
  final String userCode;

  const CompanyUserDetailPage({
    super.key,
    required this.userId,
    required this.userCode,
  });

  @override
  Widget build(BuildContext context) {
    return PersonalJobShell(
      pageTitle: 'Dettaglio utente',
      body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Codice utente: $userCode',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 24),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('userProgress')
                  .doc(userId)
                  .collection('courses')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState ==
                    ConnectionState.waiting) {
                  return const CircularProgressIndicator();
                }

                final docs = snapshot.data?.docs ?? [];

                if (docs.isEmpty) {
                  return const Text(
                    'Nessun progresso disponibile',
                  );
                }

                return Column(
                  children: docs.map((doc) {
                    final data =
                    doc.data() as Map<String, dynamic>;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        title: Text(
                          data['title'] ?? 'Corso',
                          style: const TextStyle(
                              fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          'Avanzamento: ${(data['progress'] ?? 0)}%',
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
    );
  }
}
