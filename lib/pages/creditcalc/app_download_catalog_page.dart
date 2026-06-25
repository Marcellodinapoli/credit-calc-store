import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:credit_calc_core/credit_calc_core.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/app_download_catalog_entry.dart';
import '../area/personal_area_shell.dart';
import '../../core/maintenance_service.dart';

class AppDownloadCatalogPage extends StatelessWidget {
  const AppDownloadCatalogPage({super.key});

  static const _catalogApps = <_CatalogAppDefinition>[
    _CatalogAppDefinition(
      docId: 'credit_calc_desktop',
      title: 'CreditCore tool',
      description:
          'Desktop e mobile per esattori, itinerario, creditori e provvigioni.',
      icon: Icons.devices_outlined,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return PersonalAreaShell(
      pageTitle: 'Scarica app',
      maintenanceSection: MaintenanceService.creditCalc,
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('platform_config')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = {
            for (final doc
                in snapshot.data?.docs ??
                    <QueryDocumentSnapshot<Map<String, dynamic>>>[])
              doc.id: doc.data(),
          };

          final entries = _catalogApps
              .map(
                (app) => AppDownloadCatalogEntry.fromDefinition(
                  id: app.docId,
                  title: app.title,
                  description: app.description,
                  data: docs[app.docId],
                ),
              )
              .toList();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                'Scegli l\'app o la versione da scaricare per altre piattaforme.',
                style: TextStyle(color: Colors.black54, height: 1.45),
              ),
              const SizedBox(height: 16),
              for (final app in _catalogApps)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _AppDownloadCard(
                    definition: app,
                    entry: entries.firstWhere((e) => e.id == app.docId),
                    config: docs[app.docId],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _CatalogAppDefinition {
  const _CatalogAppDefinition({
    required this.docId,
    required this.title,
    required this.description,
    required this.icon,
  });

  final String docId;
  final String title;
  final String description;
  final IconData icon;
}

class _AppDownloadCard extends StatelessWidget {
  const _AppDownloadCard({
    required this.definition,
    required this.entry,
    required this.config,
  });

  final _CatalogAppDefinition definition;
  final AppDownloadCatalogEntry entry;
  final Map<String, dynamic>? config;

  Future<void> _download(BuildContext context, {required bool mac}) async {
    final data = config ?? {};
    final url = mac
        ? ((data['macInstallerUrl'] ?? data['macDownloadUrl'] ?? '')
            .toString()
            .trim())
        : ((data['windowsInstallerUrl'] ?? data['windowsDownloadUrl'] ?? '')
            .toString()
            .trim());
    if (url.isEmpty) return;

    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final data = config ?? {};
    final windowsUrl =
        (data['windowsInstallerUrl'] ?? data['windowsDownloadUrl'] ?? '')
            .toString()
            .trim();
    final macUrl = (data['macInstallerUrl'] ?? data['macDownloadUrl'] ?? '')
        .toString()
        .trim();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: ProjectColors.area.withValues(alpha: 0.12),
                  child: Icon(definition.icon, color: ProjectColors.area),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        definition.title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        definition.description,
                        style: const TextStyle(
                          color: Colors.black54,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                Text(
                  entry.version == '—'
                      ? 'Versione non disponibile'
                      : 'Versione ${entry.version}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text('Rilascio: ${entry.formattedReleaseDate}'),
                Text(entry.formattedDownloads),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                if (windowsUrl.isNotEmpty)
                  FilledButton.icon(
                    onPressed: entry.enabled
                        ? () => _download(context, mac: false)
                        : null,
                    icon: const Icon(Icons.download_outlined),
                    label: const Text('Windows'),
                  ),
                if (macUrl.isNotEmpty)
                  FilledButton.icon(
                    onPressed: entry.enabled
                        ? () => _download(context, mac: true)
                        : null,
                    icon: const Icon(Icons.download_outlined),
                    label: const Text('macOS'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
