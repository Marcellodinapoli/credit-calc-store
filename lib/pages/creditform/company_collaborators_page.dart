// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'personal_form_shell.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../core/theme/app_card_theme.dart';
import 'package:credit_calc_core/credit_calc_core.dart' hide AppCardTheme;
import 'collaborator_course_details_page.dart';

// -----------------------------------------------------------------------------
// PAGE
// -----------------------------------------------------------------------------
class CompanyCollaboratorsPage extends StatefulWidget {
  const CompanyCollaboratorsPage({super.key});

  @override
  State<CompanyCollaboratorsPage> createState() =>
      _CompanyCollaboratorsPageState();
}

class _CompanyCollaboratorsPageState extends State<CompanyCollaboratorsPage> {
  String _companyId = '';
  late final String _myUid;
  final Set<String> _busyUserIds = {};
  bool _loadingCompany = true;

  @override
  void initState() {
    super.initState();
    _myUid = FirebaseAuth.instance.currentUser!.uid;
    _loadCompanyId();
  }

  Future<void> _loadCompanyId() async {
    final doc =
        await FirebaseFirestore.instance.collection('users').doc(_myUid).get();
    if (!mounted) return;
    setState(() {
      _companyId = (doc.data()?['companyId'] ?? '').toString();
      _loadingCompany = false;
    });
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _collaboratorsStream() {
    if (_companyId.isEmpty) {
      return FirebaseFirestore.instance
          .collection('users')
          .where('type', isEqualTo: '__none__')
          .snapshots();
    }

    return FirebaseFirestore.instance
        .collection('users')
        .where('type', isEqualTo: 'work')
        .where('companyId', isEqualTo: _companyId)
        .snapshots();
  }

  Future<String?> _promptMotivazione(
    BuildContext context, {
    required String title,
  }) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: 'Motivazione',
            hintText:
                'Descrivi il motivo della segnalazione per il backoffice (obbligatorio)',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () {
              final text = controller.text.trim();
              if (text.isEmpty) return;
              Navigator.pop(ctx, text);
            },
            child: const Text('Conferma'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  Future<void> _reportToBackoffice({
    required String userId,
    required String name,
    required String email,
    required String motivazione,
  }) async {
    if (_busyUserIds.contains(userId)) return;
    setState(() => _busyUserIds.add(userId));

    try {
      final supervisor = FirebaseAuth.instance.currentUser;
      await FirebaseFirestore.instance.collection('work_user_reports').add({
        'status': 'pending',
        'requestedAction': 'block',
        'targetUserId': userId,
        'targetEmail': email,
        'targetName': name,
        'companyId': _companyId,
        'motivazione': motivazione,
        'supervisorUid': _myUid,
        'supervisorEmail': supervisor?.email ?? '',
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Segnalazione inviata al backoffice. '
            'Il blocco sarà gestito dall’amministratore.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Invio segnalazione non riuscito: $e')),
      );
    } finally {
      if (mounted) setState(() => _busyUserIds.remove(userId));
    }
  }

  Future<void> _onReportToBackoffice(
    BuildContext context, {
    required String userId,
    required String name,
    required String email,
  }) async {
    final motivazione = await _promptMotivazione(
      context,
      title: 'Segnala al backoffice',
    );
    if (motivazione == null || !mounted) return;
    await _reportToBackoffice(
      userId: userId,
      name: name,
      email: email,
      motivazione: motivazione,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingCompany) {
      return const PersonalFormShell(
        pageTitle: 'Collaboratori azienda',
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return PersonalFormShell(
      pageTitle: 'Collaboratori azienda',
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _collaboratorsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return _emptyState();
          }

          final docs = snapshot.data!.docs
              .where((d) => d.id != _myUid)
              .toList();

          if (docs.isEmpty) {
            return _emptyState();
          }

          return ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final doc = docs[index];
              return _collaboratorCard(
                context: context,
                userId: doc.id,
                data: doc.data(),
              );
            },
          );
        },
      ),
    );
  }

  Widget _collaboratorCard({
    required BuildContext context,
    required String userId,
    required Map<String, dynamic> data,
  }) {
    final name = '${data['name'] ?? ''} ${data['surname'] ?? ''}'.trim();
    final email = data['email'] ?? '—';
    final status = UserAccountStatus.workCollaboratorStatus(
      data['status'] as String?,
    );
    final isRestricted = UserAccountStatus.isBlocked(status);
    final motivazione = UserAccountStatus.blockReason(data);
    final actionAt = UserAccountStatus.formatBlockDateTime(
      UserAccountStatus.blockDate(data),
    );
    final busy = _busyUserIds.contains(userId);

    final Timestamp? createdAt = data['createdAt'];
    final Timestamp? lastLogin = data['lastLoginAt'];

    return Card(
      color: AppCardTheme.surface,
      elevation: AppCardTheme.elevation,
      shape: AppCardTheme.shape,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.person_outline, size: 28),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    name.isEmpty ? 'Collaboratore' : name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                _statusChip(status),
              ],
            ),
            const SizedBox(height: 12),
            _kv('Email', email),
            _kv(
              'Registrato il',
              createdAt != null ? _fmtDate(createdAt.toDate()) : '—',
            ),
            _kv(
              'Ultimo login',
              lastLogin != null ? _fmtDate(lastLogin.toDate()) : '—',
            ),
            if (isRestricted) ...[
              _kv(
                status == 'standby' ? 'Data stand-by' : 'Data blocco',
                actionAt,
              ),
              _kv(
                'Motivazione',
                (motivazione != null && motivazione.isNotEmpty)
                    ? motivazione
                    : '—',
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.end,
              children: [
                if (!isRestricted)
                  OutlinedButton.icon(
                    onPressed: busy
                        ? null
                        : () => _onReportToBackoffice(
                              context,
                              userId: userId,
                              name: name.isEmpty ? 'Collaboratore' : name,
                              email: email.toString(),
                            ),
                    icon: const Icon(Icons.flag_outlined),
                    label: const Text('Segnala al backoffice'),
                  ),
                OutlinedButton.icon(
                  onPressed: busy
                      ? null
                      : () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => CollaboratorCourseDetailsPage(
                                collaboratorUserId: userId,
                                course: const CourseProgress(
                                  title: 'Progressi collaboratore',
                                  code: '',
                                ),
                              ),
                            ),
                          );
                        },
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('Apri dettagli'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _kv(String k, String v) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 140,
              child: Text(
                k,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            Expanded(child: SelectableText(v)),
          ],
        ),
      );

  Widget _statusChip(String status) {
    Color color;
    switch (status) {
      case 'active':
        color = Colors.green;
        break;
      case 'standby':
        color = Colors.orange;
        break;
      case 'blocked':
        color = Colors.red;
        break;
      default:
        color = Colors.grey;
    }

    return Chip(
      label: Text(
        UserAccountStatus.workStatusLabel(status),
        style: const TextStyle(color: Colors.white, fontSize: 12),
      ),
      backgroundColor: color,
    );
  }

  Widget _emptyState() {
    return const Center(
      child: Text(
        'Nessun collaboratore trovato.',
        style: TextStyle(color: Colors.black54),
      ),
    );
  }

  String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/'
      '${d.year} '
      '${d.hour.toString().padLeft(2, '0')}:'
      '${d.minute.toString().padLeft(2, '0')}';
}
