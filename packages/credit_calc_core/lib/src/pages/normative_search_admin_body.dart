import 'package:flutter/material.dart';

import '../ai/normative_search_admin_service.dart';
import '../ai/normative_search_config_service.dart';

/// Editor prompt Ricerca normativa (BackOffice app e web).
class NormativeSearchAdminBody extends StatefulWidget {
  const NormativeSearchAdminBody({
    super.key,
    required this.verifyAdmin,
  });

  final NormativeSearchAdminVerifier verifyAdmin;

  @override
  State<NormativeSearchAdminBody> createState() =>
      _NormativeSearchAdminBodyState();
}

class _NormativeSearchAdminBodyState extends State<NormativeSearchAdminBody> {
  bool _checkingAdmin = true;
  bool _isAdmin = false;
  bool _saving = false;
  bool _dirty = false;
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
    final ok = await widget.verifyAdmin(forceRefresh: true);
    if (!mounted) return;
    setState(() {
      _isAdmin = ok;
      _checkingAdmin = false;
    });
  }

  void _syncFromRemote(String stored) {
    if (_dirty) return;
    final text = stored.trim().isEmpty
        ? NormativeSearchConfigService.defaultSystemPrompt
        : stored;
    if (_promptCtrl.text != text) {
      _promptCtrl.text = text;
    }
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
      await NormativeSearchAdminService.savePrompt(
        prompt,
        verifyAdmin: widget.verifyAdmin,
      );
      if (!mounted) return;
      setState(() {
        _saving = false;
        _dirty = false;
      });
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

  Future<void> _restoreDefault() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ripristina prompt predefinito'),
        content: const Text(
          'Vuoi caricare il prompt predefinito nell\'editor? '
          'Salva per applicarlo in produzione.',
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
      _dirty = true;
      _promptCtrl.text = NormativeSearchConfigService.defaultSystemPrompt;
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

    return StreamBuilder<String>(
      stream: NormativeSearchConfigService.watchStoredPrompt(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData &&
            _promptCtrl.text.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        _syncFromRemote(snapshot.data ?? '');

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Prompt di sistema per l\'assistente AI in '
                'Sviluppa → Ricerca normativa. Definisce il perimetro '
                'delle risposte (recupero crediti e attività stragiudiziale).',
                style: TextStyle(color: Colors.grey.shade700, height: 1.45),
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
                        minLines: 14,
                        maxLines: 28,
                        onChanged: (_) => _dirty = true,
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
                      Row(
                        children: [
                          OutlinedButton(
                            onPressed: _saving ? null : _restoreDefault,
                            child: const Text('Ripristina predefinito'),
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
                            label: Text(
                              _saving ? 'Salvataggio…' : 'Salva prompt',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
