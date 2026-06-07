// ================================================================
// IMPORT
// ================================================================
import 'package:flutter/material.dart';
import 'personal_job_shell.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../job/job_models.dart';
import '../../job/job_repository.dart';
import '../../core/adaptive_button_styles.dart';
import '../../core/dimensions.dart';
import '../../core/theme/app_card_theme.dart';
import '../../ui/layout/adaptive_action_bar.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';

// ================================================================
// PAGE
// ================================================================
class JobDetailPage extends StatelessWidget {
  final JobOffer offer;
  final JobRepository repo;
  final bool saved;
  final bool applied;
  final VoidCallback onToggleSave;
  final VoidCallback onApply;

  const JobDetailPage({
    super.key,
    required this.offer,
    required this.repo,
    required this.saved,
    required this.applied,
    required this.onToggleSave,
    required this.onApply,
  });

  // ================================================================
  // HELPERS
  // ================================================================
  String _fmt(DateTime? d) {
    if (d == null) return "-";
    return '${d.day.toString().padLeft(2, '0')}/'
        '${d.month.toString().padLeft(2, '0')}/'
        '${d.year}';
  }

  /// ================================================================
  /// SERVICES / ACTIONS
  /// ================================================================

  Future<void> _applyToJob(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final docId = "${offer.id}_${user.uid}";
    final docRef = FirebaseFirestore.instance
        .collection('job_applications')
        .doc(docId);

    final existing = await docRef.get();
    if (existing.exists) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Hai già inviato la candidatura.")),
      );
      return;
    }

    final presentationController = TextEditingController(
      text:
      "Gentile Azienda,\n\ncon la presente desidero candidarmi per la posizione di ${offer.title}. Ritengo di possedere competenze in linea con il ruolo proposto.\n\nResto a disposizione per un colloquio.\n\nCordiali saluti.",
    );

    String? fileName;
    String? fileUrl;
    bool isUploading = false;

    if (!context.mounted) return;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            Future<void> pickAndUpload() async {
              final result = await FilePicker.platform.pickFiles(
                type: FileType.custom,
                allowedExtensions: ['pdf', 'doc', 'docx'],
                withData: true,
              );

              if (result == null || result.files.single.bytes == null) {
                return;
              }

              setStateDialog(() => isUploading = true);

              final file = result.files.single;
              fileName = file.name;
              final bytes = file.bytes!;
              final extension = file.extension ?? 'pdf';

              final storageRef = FirebaseStorage.instance
                  .ref()
                  .child("cvs/${offer.id}/${user.uid}/${DateTime.now().millisecondsSinceEpoch}_$fileName");

              try {
                final uploadTask = storageRef.putData(
                  bytes,
                  SettableMetadata(
                    contentType: extension == 'docx'
                        ? 'application/vnd.openxmlformats-officedocument.wordprocessingml.document'
                        : extension == 'doc'
                        ? 'application/msword'
                        : 'application/pdf',
                  ),
                );

                await uploadTask.whenComplete(() {});
                fileUrl = await storageRef.getDownloadURL();
              } catch (e) {
                fileUrl = null;
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Errore upload: $e")),
                );
              }

              setStateDialog(() => isUploading = false);
            }

            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              contentPadding: const EdgeInsets.all(20),
              content: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 500),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Invia candidatura",
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      const Text("Presentazione"),
                      const SizedBox(height: 6),
                      TextField(
                        controller: presentationController,
                        maxLines: 6,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),

                      Row(
                        children: [
                          ElevatedButton.icon(
                            icon: const Icon(Icons.attach_file),
                            label: const Text("Allega CV"),
                            style: AdaptiveButtonStyles.jobElevated(),
                            onPressed: isUploading ? null : pickAndUpload,
                          ),
                          if (fileName != null) ...[
                            const SizedBox(width: 10),
                            Flexible(
                              child: Text(
                                fileName!,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ],
                      ),

                      if (isUploading) ...[
                        const SizedBox(height: 12),
                        const LinearProgressIndicator(),
                      ],

                      const SizedBox(height: 20),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(dialogContext),
                            child: const Text("Annulla"),
                          ),
                          const SizedBox(width: 10),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.send),
                            label: const Text("Invia"),
                            style: AdaptiveButtonStyles.jobElevated(),
                            onPressed: (fileUrl == null || isUploading)
                                ? null
                                : () async {
                              final userDoc =
                              await FirebaseFirestore.instance
                                  .collection('users')
                                  .doc(user.uid)
                                  .get();

                              final userData = userDoc.data();

                              await docRef.set({
                                'jobId': offer.id,
                                'jobTitle': offer.title,
                                'companyId': offer.companyId,
                                'companyName': offer.company,
                                'userId': user.uid,
                                'userName': userData?['name'] ?? '',
                                'userEmail': user.email ?? '',
                                'presentation':
                                presentationController.text,
                                'cvFileName': fileName,
                                'cvUrl': fileUrl,
                                'status': 'pending',
                                'createdAt':
                                FieldValue.serverTimestamp(),
                              });

                              if (!dialogContext.mounted) return;
                              Navigator.pop(dialogContext);

                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context)
                                  .showSnackBar(
                                const SnackBar(
                                  content: Text(
                                      "Candidatura inviata correttamente."),
                                ),
                              );
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
    );
  }

// ================================================================
// BUILD
// ================================================================
  Widget _buildApplyButton(BuildContext context, User user) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('job_applications')
          .where('userId', isEqualTo: user.uid)
          .where('jobId', isEqualTo: offer.id)
          .limit(1)
          .snapshots(),
      builder: (context, snapshot) {
        final hasApplied =
            snapshot.hasData && snapshot.data!.docs.isNotEmpty;
        final now = DateTime.now();
        final isExpired =
            offer.expiryDate != null && offer.expiryDate!.isBefore(now);

        if (hasApplied) {
          return FilledButton.icon(
            style: AdaptiveButtonStyles.jobFilled(),
            icon: const Icon(Icons.check),
            label: const Text('Candidatura inviata'),
            onPressed: null,
          );
        }

        if (isExpired) {
          return FilledButton.icon(
            style: AdaptiveButtonStyles.jobFilled(),
            icon: const Icon(Icons.block),
            label: const Text('Offerta scaduta'),
            onPressed: null,
          );
        }

        return FilledButton.icon(
          style: AdaptiveButtonStyles.jobFilled(),
          icon: const Icon(Icons.send),
          label: const Text('Candidati'),
          onPressed: () async {
            await _applyToJob(context);
          },
        );
      },
    );
  }

  List<Widget> _buildDetailSections(
    BuildContext context,
    User? user, {
    required bool includeApply,
  }) {
    return [
      FutureBuilder<CompanyInfo?>(
        future: repo.fetchCompanyById(offer.companyId),
        builder: (context, companySnapshot) {
          final company = companySnapshot.data;

          return _infoCard(
            title: "Informazioni principali",
            children: [
              _kv("Titolo", offer.title),
              _kv("Azienda", offer.company),
              _kv("Sede", offer.location),
              _kv("Modalità", offer.mode.name),
              _kv("Data pubblicazione", _fmt(offer.date)),
              if (company != null) ...[
                _kv("ID Azienda", company.companyId),
                _kv("P.IVA", company.vat),
                _kv("Sede legale", company.hqCity),
              ],
            ],
          );
        },
      ),
      const SizedBox(height: 16),
      _infoCard(
        title: "Dettagli posizione",
        children: [
          if (offer.level != null) _kv("Livello", offer.level!),
          if (offer.department != null)
            _kv("Dipartimento", offer.department!),
          if (offer.role != null) _kv("Ruolo", offer.role!),
          if (offer.positions != null)
            _kv("Numero posizioni", offer.positions.toString()),
          if (offer.education != null)
            _kv("Formazione richiesta", offer.education!),
          if (offer.experience != null)
            _kv("Esperienza", offer.experience!),
          if (offer.salary != null)
            _kv("Retribuzione", offer.salary!),
          if (offer.schedule != null)
            _kv("Orario", offer.schedule!),
          if (offer.expiryDate != null)
            _kv("Scadenza", _fmt(offer.expiryDate)),
          if (offer.status != null)
            _kv("Stato", offer.status!),
        ],
      ),
      const SizedBox(height: 16),
      _infoCard(
        title: "Competenze",
        children: [
          if (offer.skills != null)
            _multiline(
              "Competenze richieste",
              offer.skills is List
                  ? (offer.skills as List)
                      .map((s) => s is Map
                          ? ((s['required'] == true)
                              ? "${s['value']} (obbligatorio)"
                              : s['value'])
                          : s.toString())
                      .join(", ")
                  : offer.skills.toString(),
            ),
          if (offer.niceSkills != null)
            _multiline("Competenze preferenziali", offer.niceSkills!),
        ],
      ),
      const SizedBox(height: 16),
      _infoCard(
        title: "Descrizione",
        children: [
          Text(
            offer.description,
            style: const TextStyle(height: 1.5),
          ),
        ],
      ),
      const SizedBox(height: 16),
      _infoCard(
        title: "Benefit e Attività",
        children: [
          if (offer.benefits != null)
            _multiline("Benefit", offer.benefits!),
          if (offer.tasks != null)
            _multiline("Attività previste", offer.tasks!),
        ],
      ),
      const SizedBox(height: 16),
      _infoCard(
        title: "Contatti",
        children: [
          if (offer.referencePerson != null)
            _kv("Referente", offer.referencePerson!),
          if (offer.hrEmail != null)
            _kv("Email HR", offer.hrEmail!),
        ],
      ),
      if (includeApply && user != null) ...[
        const SizedBox(height: 20),
        _infoCard(
          title: "Candidatura",
          children: [
            Align(
              alignment: Alignment.center,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 300),
                child: _buildApplyButton(context, user),
              ),
            ),
          ],
        ),
      ],
    ];
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final compact = Dimensions.isPhone(context);
    final sections = _buildDetailSections(context, user, includeApply: !compact);

    if (!compact) {
      return PersonalJobShell(
        pageTitle: offer.title,
        body: ListView(
          padding: Dimensions.scrollPadding(context),
          children: sections,
        ),
      );
    }

    return PersonalJobShell(
      pageTitle: offer.title,
      bottomBar: user == null
          ? null
          : AdaptiveActionBar(
              actions: [
                AdaptiveActionBarAction(
                  child: _buildApplyButton(context, user),
                ),
              ],
            ),
      body: ListView(
        padding: Dimensions.scrollPadding(context),
        children: sections,
      ),
    );
  }
  // ================================================================
// UI HELPERS
// ================================================================

  Widget _infoCard({
    required String title,
    required List<Widget> children,
  }) {
    return Card(
      color: AppCardTheme.surface,
      elevation: AppCardTheme.elevation,
      shape: AppCardTheme.shape,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment:
          CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _kv(String k, String v) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(
      crossAxisAlignment:
      CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 200,
          child: Text(
            k,
            style: const TextStyle(
                fontWeight: FontWeight.w600),
          ),
        ),
        Expanded(child: Text(v)),
      ],
    ),
  );

  Widget _multiline(String k, dynamic v) {
    if (v == null) return const SizedBox.shrink();

    String text = '';

    if (v is String) {
      if (v.trim().isEmpty) return const SizedBox.shrink();
      text = v;
    }
    else if (v is List) {
      if (v.isEmpty) return const SizedBox.shrink();

      text = v.map((e) {
        if (e is Map && e['value'] != null) {
          final name = e['value'].toString();

          final requiredRaw = e['required'];
          final required =
              requiredRaw == true ||
                  requiredRaw == 'true' ||
                  requiredRaw == 1;

          return required ? '$name (obbligatorio)' : name;
        }
        return e.toString();
      })
          .where((e) => e.trim().isNotEmpty)
          .join(', ');

      if (text.trim().isEmpty) return const SizedBox.shrink();
    }
    else {
      text = v.toString();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Text(
            k,
            style: const TextStyle(
                fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            text,
            style: const TextStyle(height: 1.5),
          ),
        ],
      ),
    );
  }
}