import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../../core/dimensions.dart';
import 'personal_area_shell.dart';

// ================================================================
// PAGE
// ================================================================
class PrivacyConsentsPage extends StatefulWidget {
  const PrivacyConsentsPage({super.key});

  @override
  State<PrivacyConsentsPage> createState() => _PrivacyConsentsPageState();
}

// ================================================================
// STATE
// ================================================================
class _PrivacyConsentsPageState extends State<PrivacyConsentsPage> {
  bool _loading = true;

  List<Map<String, dynamic>> historyStaff = [];
  List<Map<String, dynamic>> historyCompanies = [];

  // ❌ RIMOSSI CONSENSI
  // bool _currentStaff = false;
  // bool _currentCompanies = false;

  String? rulesVersion;
  DateTime? rulesAcceptedAt;
  String rulesText = '';

  // 🔥 STORICO REGOLE
  List<Map<String, dynamic>> rulesHistory = [];

  bool _expandedRules = false;

  String? get uid => FirebaseAuth.instance.currentUser?.uid;

  // ================================================================
  // LIFECYCLE
  // ================================================================
  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  // ================================================================
  // SERVICES
  // ================================================================
  Future<void> _loadHistory() async {
    if (uid == null) {
      setState(() => _loading = false);
      return;
    }

    final firestore = FirebaseFirestore.instance;

    // ❌ RIMOSSO BLOCCO CONSENSI UTENTE

    // 🔹 accettazione regolamento azienda (corrente)
    final companyDoc =
    await firestore.collection('companies').doc(uid).get();

    if (companyDoc.exists) {
      final data = companyDoc.data() as Map<String, dynamic>;

      rulesVersion = data['rulesAcceptedVersion']?.toString();

      if (data['rulesAcceptedAt'] is Timestamp) {
        rulesAcceptedAt =
            (data['rulesAcceptedAt'] as Timestamp).toDate();
      }

      if (rulesVersion != null) {
        final versionDoc = await firestore
            .collection('settings')
            .doc('job_offer_rules')
            .collection('versions')
            .doc(rulesVersion)
            .get();

        final versionData = versionDoc.data();

        if (versionData != null) {
          rulesText = (versionData['text'] ?? '').toString();
        }
      }
    }

    // 🔥 STORICO REGOLE
    final historySnap = await firestore
        .collection('companies')
        .doc(uid)
        .collection('rules_history')
        .orderBy('acceptedAt', descending: true)
        .get();

    rulesHistory = [];

    for (final doc in historySnap.docs) {
      final data = doc.data();

      String version = data['version']?.toString() ?? '-';

      DateTime? acceptedAt;
      if (data['acceptedAt'] is Timestamp) {
        acceptedAt =
            (data['acceptedAt'] as Timestamp).toDate();
      }

      String text = '';

      final versionDoc = await firestore
          .collection('settings')
          .doc('job_offer_rules')
          .collection('versions')
          .doc(version)
          .get();

      final versionData = versionDoc.data();
      if (versionData != null) {
        text = (versionData['text'] ?? '').toString();
      }

      rulesHistory.add({
        'version': version,
        'acceptedAt': acceptedAt,
        'text': text,
      });
    }

    setState(() => _loading = false);
  }

  // ================================================================
  // HELPERS
  // ================================================================
  String _formatDate(DateTime? d) {
    if (d == null) return '-';
    return '${d.day}/${d.month}/${d.year}';
  }

  // ================================================================
// BUILD
// ================================================================
  @override
  Widget build(BuildContext context) {
    return PersonalAreaShell(
      pageTitle: 'Privacy e consensi',
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
            padding: Dimensions.scrollPadding(context),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Informazioni su privacy, cookie e consensi collegati al tuo account.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 24),
                _section(
                  context,
                  title: 'Privacy Policy',
                  text:
                      'La piattaforma tratta i dati personali in conformità al GDPR. '
                      'Puoi consultare finalità, diritti dell\'utente e modalità di '
                      'trattamento. Le preferenze possono essere aggiornate in '
                      'qualsiasi momento da questa sezione.',
                ),
                _section(
                  context,
                  title: 'Cookie e consenso',
                  text:
                      'Al primo accesso puoi gestire cookie tecnici, statistici e di '
                      'marketing tramite il banner in basso a sinistra («Gestisci '
                      'consenso»). Le scelte restano memorizzate sul dispositivo.',
                ),
                if (rulesVersion != null) ...[
                  const SizedBox(height: 8),
                  _section(
                    context,
                    title: 'Regole pubblicazione offerte',
                    text:
                        'Se gestisci un\'azienda, qui trovi il regolamento che hai '
                        'accettato per pubblicare offerte di lavoro.',
                  ),
                ],

                // ================================================================
                // REGOLAMENTO CORRENTE
                // ================================================================
                if (rulesVersion != null)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment:
                        CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Regole pubblicazione offerte (corrente)',
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Text('Versione: $rulesVersion'),
                          Text(
                              'Accettato il: ${_formatDate(rulesAcceptedAt)}'),
                          const SizedBox(height: 16),

                          AnimatedCrossFade(
                            firstChild: Column(
                              crossAxisAlignment:
                              CrossAxisAlignment.start,
                              children: [
                                SizedBox(
                                  height: 150,
                                  child: SingleChildScrollView(
                                    physics:
                                    const NeverScrollableScrollPhysics(),
                                    child: MarkdownBody(
                                      data: rulesText,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _expandedRules = true;
                                    });
                                  },
                                  child: const Text(
                                    'Continua a leggere',
                                    style: TextStyle(
                                      color: Colors.blue,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            secondChild: Column(
                              crossAxisAlignment:
                              CrossAxisAlignment.start,
                              children: [
                                MarkdownBody(data: rulesText),
                                const SizedBox(height: 8),
                                GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _expandedRules = false;
                                    });
                                  },
                                  child: const Text(
                                    'Riduci',
                                    style: TextStyle(
                                      color: Colors.blue,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            crossFadeState: _expandedRules
                                ? CrossFadeState.showSecond
                                : CrossFadeState.showFirst,
                            duration:
                            const Duration(milliseconds: 200),
                          ),
                        ],
                      ),
                    ),
                  ),

                const SizedBox(height: 16),

                // ================================================================
                // STORICO REGOLE
                // ================================================================
                if (rulesHistory.isNotEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment:
                        CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Storico accettazioni',
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 12),

                          ...rulesHistory.map((item) {

                            bool expanded = item['expanded'] == true;

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: Column(
                                crossAxisAlignment:
                                CrossAxisAlignment.start,
                                children: [
                                  Text('Versione: ${item['version']}'),
                                  Text(
                                      'Accettato il: ${_formatDate(item['acceptedAt'])}'),
                                  const SizedBox(height: 8),

                                  AnimatedCrossFade(
                                    firstChild: Column(
                                      crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                      children: [
                                        SizedBox(
                                          height: 120,
                                          child: SingleChildScrollView(
                                            physics:
                                            const NeverScrollableScrollPhysics(),
                                            child: MarkdownBody(
                                              data: item['text'] ?? '',
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        GestureDetector(
                                          onTap: () {
                                            setState(() {
                                              item['expanded'] = true;
                                            });
                                          },
                                          child: const Text(
                                            'Continua a leggere',
                                            style: TextStyle(
                                              color: Colors.blue,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    secondChild: Column(
                                      crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                      children: [
                                        MarkdownBody(
                                          data: item['text'] ?? '',
                                        ),
                                        const SizedBox(height: 6),
                                        GestureDetector(
                                          onTap: () {
                                            setState(() {
                                              item['expanded'] = false;
                                            });
                                          },
                                          child: const Text(
                                            'Riduci',
                                            style: TextStyle(
                                              color: Colors.blue,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    crossFadeState: expanded
                                        ? CrossFadeState.showSecond
                                        : CrossFadeState.showFirst,
                                    duration:
                                    const Duration(milliseconds: 200),
                                  ),

                                  const Divider(),
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
      ),
    );
  }

  Widget _section(
    BuildContext context, {
    required String title,
    required String text,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            text,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}