import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../subscription/ecosystem_sections.dart';
import '../subscription/ecosystem_sections_admin_service.dart';
import '../subscription/ecosystem_sections_config_service.dart';

/// Editor testi sezioni CreditForm / CreditCalc / CreditJob (BackOffice app e web).
class EcosystemSectionsAdminBody extends StatefulWidget {
  const EcosystemSectionsAdminBody({
    super.key,
    required this.verifyAdmin,
  });

  final EcosystemSectionsAdminVerifier verifyAdmin;

  @override
  State<EcosystemSectionsAdminBody> createState() =>
      _EcosystemSectionsAdminBodyState();
}

class _EcosystemSectionsAdminBodyState extends State<EcosystemSectionsAdminBody>
    with SingleTickerProviderStateMixin {
  bool _checkingAdmin = true;
  bool _isAdmin = false;
  bool _saving = false;
  String? _formError;
  String? _loadWarning;
  bool _formDirty = false;
  late final TabController _tabs;
  StreamSubscription<Map<String, dynamic>?>? _sectionsSubscription;

  final Map<String, Map<String, dynamic>> _sectionPayloads = {};

  @override
  void initState() {
    super.initState();
    _tabs = TabController(
      length: EcosystemSectionsAdminService.sectionIds.length,
      vsync: this,
    );
    _loadAdmin();
  }

  @override
  void dispose() {
    _sectionsSubscription?.cancel();
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _loadAdmin() async {
    final ok = await widget.verifyAdmin(forceRefresh: true);
    if (!mounted) return;

    if (ok) {
      await _refreshFromFirestore();
      _sectionsSubscription?.cancel();
      _sectionsSubscription =
          EcosystemSectionsConfigService.watchSectionsConfig().listen(
        (sections) {
          if (!mounted || _formDirty) return;
          setState(() {
            _loadWarning = null;
            EcosystemSectionsAdminService.applySectionsConfig(
              sections: sections,
              onSection: (sectionId, payload) {
                _sectionPayloads[sectionId] = {
                  ...payload,
                  'sectionId': sectionId,
                };
              },
            );
          });
        },
        onError: (_) {
          if (!mounted) return;
          setState(() {
            _loadWarning ??=
                'Impossibile sincronizzare da Firestore. '
                'Modifica e salva per creare il documento.';
          });
        },
      );
    }

    setState(() {
      _isAdmin = ok;
      _checkingAdmin = false;
    });
  }

  Future<void> _refreshFromFirestore() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('settings')
          .doc(EcosystemSectionsConfigService.docId)
          .get(const GetOptions(source: Source.server));
      if (!mounted) return;
      final data = snapshot.data();
      final sections = data?['sections'];
      final sectionsMap = sections is Map<String, dynamic>
          ? sections
          : sections is Map
              ? Map<String, dynamic>.from(sections)
              : null;
      setState(() {
        _loadWarning = null;
        _formDirty = false;
        EcosystemSectionsAdminService.applySectionsConfig(
          sections: sectionsMap,
          onSection: (sectionId, payload) {
            _sectionPayloads[sectionId] = {...payload, 'sectionId': sectionId};
          },
        );
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadWarning ??=
            'Lettura Firestore non riuscita. '
            'Controlla connessione e regole, poi riprova.';
        EcosystemSectionsAdminService.applySectionsConfig(
          sections: null,
          onSection: (sectionId, payload) {
            _sectionPayloads[sectionId] = {...payload, 'sectionId': sectionId};
          },
        );
      });
    }
  }

  Map<String, dynamic> _payloadFor(String sectionId) {
    return _sectionPayloads.putIfAbsent(
      sectionId,
      () => EcosystemSectionsAdminService.buildSectionFormPayload(sectionId, null)
        ..['sectionId'] = sectionId,
    );
  }

  void _updatePayload(String sectionId, Map<String, dynamic> patch) {
    _formDirty = true;
    _sectionPayloads[sectionId] = {
      ..._payloadFor(sectionId),
      ...patch,
      'sectionId': sectionId,
    };
    setState(() {});
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _formError = null;
    });

    try {
      final sections = <String, Map<String, dynamic>>{
        for (final sectionId in EcosystemSectionsAdminService.sectionIds)
          sectionId: EcosystemSectionsAdminService.buildFirestoreSectionPayload(
            sectionId,
            _payloadFor(sectionId),
          ),
      };
      await EcosystemSectionsAdminService.saveSections(
        sections,
        verifyAdmin: widget.verifyAdmin,
      );
      if (!mounted) return;
      setState(() {
        _saving = false;
        _formDirty = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sezioni ecosistema salvate.')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _formError = e.toString().replaceFirst('StateError: ', '');
      });
    }
  }

  Future<void> _restoreDefaults() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ripristina testi predefiniti'),
        content: const Text(
          'Vuoi ripristinare i testi predefiniti di tutte le sezioni? '
          'Le modifiche non salvate andranno perse.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Ripristina'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() {
      _formDirty = true;
      EcosystemSectionsAdminService.applySectionsConfig(
        sections: null,
        onSection: (sectionId, payload) {
          _sectionPayloads[sectionId] = {...payload, 'sectionId': sectionId};
        },
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_checkingAdmin) {
      return const Center(child: CircularProgressIndicator());
    }
    if (!_isAdmin) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Accesso riservato agli amministratori backoffice.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Text(
            'Testi delle card descrittive CreditForm, CreditCalc e CreditJob '
            'mostrate in home pubblica, pagina prezzi e registrazione.',
            style: TextStyle(color: Colors.grey.shade700, height: 1.45),
          ),
        ),
        if (_loadWarning != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Text(
              _loadWarning!,
              style: TextStyle(color: Colors.orange.shade800, fontSize: 13),
            ),
          ),
        TabBar(
          controller: _tabs,
          isScrollable: true,
          tabs: [
            for (final id in EcosystemSectionsAdminService.sectionIds)
              Tab(text: defaultEcosystemSectionForId(id).title),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabs,
            children: [
              for (final id in EcosystemSectionsAdminService.sectionIds)
                _SectionEditor(
                  payload: _payloadFor(id),
                  onChanged: (patch) => _updatePayload(id, patch),
                ),
            ],
          ),
        ),
        if (_formError != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              _formError!,
              style: TextStyle(color: Colors.red.shade700),
            ),
          ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              OutlinedButton(
                onPressed: _saving ? null : _restoreDefaults,
                child: const Text('Ripristina predefiniti'),
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.save_outlined),
                label: const Text('Salva'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SectionEditor extends StatelessWidget {
  const _SectionEditor({
    required this.payload,
    required this.onChanged,
  });

  final Map<String, dynamic> payload;
  final ValueChanged<Map<String, dynamic>> onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            key: ValueKey('title-${payload['sectionId']}'),
            initialValue: payload['title']?.toString() ?? '',
            decoration: const InputDecoration(
              labelText: 'Titolo',
              border: OutlineInputBorder(),
            ),
            onChanged: (value) => onChanged({'title': value}),
          ),
          const SizedBox(height: 12),
          TextField(
            key: ValueKey('subtitle-${payload['sectionId']}'),
            initialValue: payload['subtitle']?.toString() ?? '',
            decoration: const InputDecoration(
              labelText: 'Sottotitolo',
              border: OutlineInputBorder(),
            ),
            onChanged: (value) => onChanged({'subtitle': value}),
          ),
          const SizedBox(height: 12),
          TextField(
            key: ValueKey('body-${payload['sectionId']}'),
            initialValue: payload['body']?.toString() ?? '',
            minLines: 4,
            maxLines: 8,
            decoration: const InputDecoration(
              labelText: 'Testo descrittivo',
              alignLabelWithHint: true,
              border: OutlineInputBorder(),
            ),
            onChanged: (value) => onChanged({'body': value}),
          ),
          const SizedBox(height: 12),
          TextField(
            key: ValueKey('highlights-${payload['sectionId']}'),
            initialValue: payload['highlightsText']?.toString() ?? '',
            minLines: 6,
            maxLines: 12,
            decoration: const InputDecoration(
              labelText: 'Elenco puntato (una voce per riga)',
              alignLabelWithHint: true,
              border: OutlineInputBorder(),
            ),
            onChanged: (value) => onChanged({'highlightsText': value}),
          ),
        ],
      ),
    );
  }
}
