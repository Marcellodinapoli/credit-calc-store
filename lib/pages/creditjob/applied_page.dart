import 'package:flutter/material.dart';
import 'personal_job_shell.dart';
import '../../job/job_models.dart';
import 'job_widgets.dart';

class AppliedPage extends StatelessWidget {
  final List<JobOffer> allOffers;
  final Set<String> appliedIds;

  const AppliedPage({
    super.key,
    required this.allOffers,
    required this.appliedIds,
  });

  @override
  Widget build(BuildContext context) {
    final appliedOffers = allOffers
        .where((o) => appliedIds.contains(o.id))
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    return PersonalJobShell(
      pageTitle: 'Candidature inviate',
      body: appliedOffers.isEmpty
          ? const Center(child: Text('Non hai ancora inviato candidature.'))
          : ListView.builder(
        itemCount: appliedOffers.length,
        itemBuilder: (_, i) {
          final o = appliedOffers[i];
          return Card(
            margin: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: ListTile(
              contentPadding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              title: Row(
                children: [
                  Expanded(
                    child: Text(
                      o.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  ModeBadge(mode: o.mode),
                ],
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 6,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.business_outlined,
                            size: 16,
                            color: Colors.black45,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            o.company,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const Text(
                        '•',
                        style: TextStyle(color: Colors.black38),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.place,
                            size: 16,
                            color: Colors.black45,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            o.location,
                            style: const TextStyle(color: Colors.black54),
                          ),
                        ],
                      ),
                      const SizedBox(width: 6),
                      const AppliedPill(),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
