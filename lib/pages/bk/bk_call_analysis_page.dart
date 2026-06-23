import 'package:flutter/material.dart';

import '../../core/admin/bk_admin_service.dart';
import '../../core/admin/call_analysis_admin_service.dart';
import '../../services/call_analysis_config_service.dart';
import '../area/personal_area_shell.dart';

/// Backoffice — prompt di sistema per Analisi telefonata.
class BkCallAnalysisPage extends StatefulWidget {
  const BkCallAnalysisPage({super.key});

  @override
  State<BkCallAnalysisPage> createState() => _BkCallAnalysisPageState();
}

class _BkCallAnalysisPageState extends State<BkCallAnalysisPage> {
  bool _checkingAdmin = true;
  bool _isAdmin = false;
  bool _saving = false;
  String? _formError;
  final _promptCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadAdmin();
  }

  @override
  void dispose() {
    _promptCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAdmin() async {
    final ok = await BkAdminService.isAdmin(forceRefresh: true);
    if (!mounted) return;
    setState(() {
      _isAdmin = ok;
      _checkingAdmin = false;
    });
  }

  Future<void> _save() async {
    final prompt = _promptCtrl.text.trim();
    if (prompt.isEmpty) {
      setState(() => _formError = 'Inserisci il prompt di sistema.');
      return;
    }

    setState(() {
      _saving = true;
      _formError = null;
    });

    try {
      await CallAnalysisAdminService.savePrompt(prompt);
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Prompt salvato.')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _formError = e.toString().replaceFirst('StateError: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PersonalAreaShell(
      pageTitle: 'Prompt analisi telefonata',
      body: _checkingAdmin
          ? const Center(child: CircularProgressIndicator())
          : !_isAdmin
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Accesso riservato agli amministratori backoffice.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : StreamBuilder<String>(
                  stream: CallAnalysisConfigService.watchPrompt(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting &&
                        !snapshot.hasData &&
                        _promptCtrl.text.isEmpty) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final remote = snapshot.data ?? '';
                    if (_promptCtrl.text.isEmpty && remote.isNotEmpty) {
                      _promptCtrl.text = remote;
                    }

                    return SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Configura il prompt usato dalla pagina Strumenti '
                            '«Analisi telefonata» per suggerire le leve '
                            'negoziali in base ai dati pratica.',
                            style: TextStyle(
                              fontSize: 15,
                              color: Colors.grey.shade700,
                              height: 1.45,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  TextField(
                                    controller: _promptCtrl,
                                    minLines: 12,
                                    maxLines: 24,
                                    decoration: const InputDecoration(
                                      labelText: 'Prompt di sistema',
                                      alignLabelWithHint: true,
                                      border: OutlineInputBorder(),
                                    ),
                                  ),
                                  if (_formError != null) ...[
                                    const SizedBox(height: 12),
                                    Text(
                                      _formError!,
                                      style: TextStyle(color: Colors.red.shade700),
                                    ),
                                  ],
                                  const SizedBox(height: 16),
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
                                    label: Text(
                                      _saving ? 'Salvataggio…' : 'Salva prompt',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}
