// -----------------------------------------------------------------------------
// IMPORT
// -----------------------------------------------------------------------------
import 'package:flutter/material.dart';
import 'personal_job_shell.dart';
import 'package:cloud_firestore/cloud_firestore.dart';


// -----------------------------------------------------------------------------
// PAGE ROOT
// -----------------------------------------------------------------------------
class JobOfferPreviewPage extends StatelessWidget {
  final String jobId;

  const JobOfferPreviewPage({
    super.key,
    required this.jobId,
  });

  // ---------------------------------------------------------------------------
// BUILD
// ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return PersonalJobShell(
      pageTitle: 'Anteprima offerta',
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('job_offers')
            .doc(jobId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('Offerta non trovata'));
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;

          // --- RAL parsing
          String ralFormatted = '';
          final ralMin = data['salaryMin'];
          final ralMax = data['salaryMax'];

          if (ralMin != null && ralMax != null) {
            ralFormatted = '$ralMin - $ralMax €';
          } else if (ralMin != null) {
            ralFormatted = 'Da $ralMin €';
          } else if (ralMax != null) {
            ralFormatted = 'Fino a $ralMax €';
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _statusBadge(data['status'] as String?),
                const SizedBox(height: 12),

                Text(
                  data['title'] as String? ?? '',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 8),

                _metaRow('Sede', data['location'] as String?),
                _metaRow('Modalità', data['workMode'] as String?),
                _metaRow('Contratto', data['contractType'] as String?),
                _metaRow('Orario', data['schedule'] as String?),
                _metaRow('Posizioni aperte', data['positions']?.toString()),
                _metaRow('Retribuzione', _buildSalaryComplete(data)),
                _metaRow('RAL', ralFormatted),

                const Divider(height: 32),

                _section('Descrizione ruolo', data['description']),
                _section('Competenze richieste', data['skills']),
                _section('Benefit', data['benefits']),

                const Divider(height: 32),

                _section('Titolo di studio', data['education']),
                _section('Esperienza richiesta', data['experience']),

                const SizedBox(height: 24),

                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Questa è un’anteprima dell’offerta come verrà vista dai candidati. '
                        'Non è possibile candidarsi da questa schermata.',
                    style: TextStyle(fontStyle: FontStyle.italic),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

// ---------------------------------------------------------------------------
// UI HELPERS
// ---------------------------------------------------------------------------

  Widget _section(String title, dynamic value) {
    if (value == null) return const SizedBox.shrink();

    String text = '';

    if (value is String) {
      if (value.trim().isEmpty) return const SizedBox.shrink();
      text = value;
    } else if (value is List) {
      if (value.isEmpty) return const SizedBox.shrink();
      text = value
          .map((e) {
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
    } else {
      text = value.toString();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 6),
          Text(text),
        ],
      ),
    );
  }

  Widget _metaRow(String label, String? value) {
    if (value == null || value.trim().isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          SizedBox(
            width: 160,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Widget _statusBadge(String? status) {
    Color color;
    String label;

    switch (status) {
      case 'approved':
        color = Colors.green;
        label = 'Approvata';
        break;
      case 'rejected':
        color = Colors.red;
        label = 'Rifiutata';
        break;
      default:
        color = Colors.orange;
        label = 'In approvazione';
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: Chip(
        backgroundColor: color,
        label: Text(
          label,
          style: const TextStyle(color: Colors.white),
        ),
      ),
    );
  }

  String? _buildSalaryComplete(Map<String, dynamic> data) {
    final salary = data['salary'];
    final from = data['salaryFrom'];
    final to = data['salaryTo'];
    final min = data['salaryMin'];
    final max = data['salaryMax'];

    if (salary != null && salary.toString().trim().isNotEmpty) {
      return salary.toString();
    }

    if (from != null && to != null) {
      return '$from - $to';
    }

    if (min != null && max != null) {
      return '$min - $max';
    }

    if (min != null) return min.toString();
    if (max != null) return max.toString();

    return null;
  }
}