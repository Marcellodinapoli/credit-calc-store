import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/maintenance_service.dart';
import '../../models/building_resident_entry.dart';
import '../../services/building_residents_lookup_service.dart';
import '../../services/directory/pagine_gialle_directory_service.dart';
import '../../services/directory/telextra_directory_service.dart';
import '../../ui/layout/page_shell.dart';
import '../../widgets/address_field_with_scan.dart';
import '../../widgets/maintenance_section_gate.dart';

/// Ricerca nominativi a un indirizzo tramite elenchi pubblici web (senza dati CreditCalc).
class BuildingResidentsLookupPage extends StatefulWidget {
  const BuildingResidentsLookupPage({super.key});

  @override
  State<BuildingResidentsLookupPage> createState() =>
      _BuildingResidentsLookupPageState();
}

class _BuildingResidentsLookupPageState extends State<BuildingResidentsLookupPage> {
  final _addressCtrl = TextEditingController();
  bool _loading = false;
  String? _error;
  BuildingResidentsLookupResult? _result;

  @override
  void dispose() {
    _addressCtrl.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final address = _addressCtrl.text.trim();
    if (address.length < 5) {
      setState(() => _error = 'Inserisci via, civico e città.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _result = null;
    });

    try {
      final result = await BuildingResidentsLookupService.lookup(address);
      if (!mounted) return;
      setState(() {
        _result = result;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString().replaceFirst('ArgumentError: ', '');
      });
    }
  }

  Future<void> _openUri(Uri Function(String) builder) async {
    final address = (_result?.queryAddress ?? _addressCtrl.text).trim();
    if (address.length < 5) {
      setState(() => _error = 'Inserisci via, civico e città prima di aprire il sito.');
      return;
    }
    await launchUrl(
      builder(address),
      mode: LaunchMode.externalApplication,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SecondaryPageScaffold(
      pageTitle: 'Ricerca per indirizzo',
      project: BrandedPageProject.calc,
      body: MaintenanceSectionGate(
        sectionName: MaintenanceService.creditCalc,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
              Text(
                'Inserisci via, numero civico e città. CreditCalc consulta '
                'Pagine Bianche, Pagine Gialle, Telextra (1188) e altri '
                'motori web pubblici (DuckDuckGo, Bing) per trovare nominativi '
                'collegati all\'indirizzo. Non vengono usati dati delle tue pratiche.',
                style: TextStyle(color: Colors.grey.shade700, height: 1.45),
              ),
              const SizedBox(height: 8),
              Text(
                'Gli elenchi telefonici pubblici non sono mai completi: usa il '
                'risultato come supporto operativo, non come certificazione '
                'anagrafica.',
                style: TextStyle(
                  color: Colors.orange.shade800,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),
              AddressFieldWithScan(
                controller: _addressCtrl,
                labelText: 'Indirizzo (via, civico, città)',
                hintText: 'Es. Via Roma 10, 80100 Napoli',
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _loading ? null : _search,
                icon: const Icon(Icons.search),
                label: const Text('Cerca nominativi'),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: _loading
                        ? null
                        : () => _openUri(
                              BuildingResidentsLookupService.pagineBiancheWebUri,
                            ),
                    icon: const Icon(Icons.open_in_new, size: 18),
                    label: const Text('Pagine Bianche'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _loading
                        ? null
                        : () => _openUri(
                              PagineGialleDirectoryService.searchUri,
                            ),
                    icon: const Icon(Icons.open_in_new, size: 18),
                    label: const Text('Pagine Gialle'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _loading
                        ? null
                        : () => _openUri(TelextraDirectoryService.webSearchUri),
                    icon: const Icon(Icons.open_in_new, size: 18),
                    label: const Text('1188 / Telextra'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _loading
                        ? null
                        : () => _openUri(BuildingResidentsLookupService.bingWebUri),
                    icon: const Icon(Icons.open_in_new, size: 18),
                    label: const Text('Bing'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _loading
                        ? null
                        : () => _openUri(
                              BuildingResidentsLookupService.googleWebUri,
                            ),
                    icon: const Icon(Icons.open_in_new, size: 18),
                    label: const Text('Google'),
                  ),
                ],
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(
                  _error!,
                  style: TextStyle(color: Colors.red.shade700),
                ),
              ],
              if (_loading) ...[
                const SizedBox(height: 24),
                const Center(child: CircularProgressIndicator()),
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    'Consulto elenchi pubblici…',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ),
              ],
              if (_result != null) ...[
                const SizedBox(height: 24),
                _SummaryCard(result: _result!),
                const SizedBox(height: 16),
                if (_result!.residents.isEmpty)
                  Text(
                    'Nessun nominativo trovato.',
                    style: TextStyle(color: Colors.grey.shade700),
                  )
                else
                  ..._result!.residents.map(
                    (entry) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _ResidentCard(entry: entry),
                    ),
                  ),
              ],
            ],
          ),
        ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.result});

  final BuildingResidentsLookupResult result;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${result.residents.length} nominativi',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Indirizzo: ${result.queryAddress}',
              style: TextStyle(color: Colors.grey.shade700, height: 1.4),
            ),
            const SizedBox(height: 8),
            Text(
              'Fonti con risultati: ${result.searchedSources.isEmpty ? 'nessuna' : result.searchedSources.join(' · ')}',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
            const SizedBox(height: 4),
            Text(
              'Motori consultati: ${result.consultedSources.join(' · ')}',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
            if (result.notes != null && result.notes!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                result.notes!,
                style: TextStyle(
                  color: Colors.blue.shade800,
                  height: 1.45,
                  fontSize: 13,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ResidentCard extends StatelessWidget {
  const _ResidentCard({required this.entry});

  final BuildingResidentEntry entry;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(entry.displayName),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (entry.address.isNotEmpty) Text(entry.address),
            const SizedBox(height: 4),
            Text(
              entry.sourceLabel +
                  (entry.category != null && entry.category!.isNotEmpty
                      ? ' · ${entry.category}'
                      : ''),
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
          ],
        ),
        trailing: entry.phone != null && entry.phone!.isNotEmpty
            ? Text(
                entry.phone!,
                style: const TextStyle(fontWeight: FontWeight.w600),
              )
            : null,
        isThreeLine: true,
      ),
    );
  }
}
