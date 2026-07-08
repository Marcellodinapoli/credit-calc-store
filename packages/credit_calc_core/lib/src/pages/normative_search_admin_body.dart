import 'package:flutter/material.dart';

import '../ai/ai_usage_admin_service.dart';
import '../ai/normative_search_admin_service.dart';
import '../ai/normative_search_config_service.dart';
import '../core/euro_format.dart';
import '../widgets/normative_search_history_section.dart';

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
              const _AiUsageMonthCard(),
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
              const SizedBox(height: 24),
              const NormativeSearchHistorySection(),
            ],
          ),
        );
      },
    );
  }
}

class _AiUsageMonthCard extends StatelessWidget {
  const _AiUsageMonthCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: StreamBuilder<AiUsageMonthStats>(
          stream: AiUsageAdminService.watchCurrentMonthTotals(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Text(
                'Impossibile caricare l\'utilizzo AI del mese.',
                style: TextStyle(color: Colors.red.shade700),
              );
            }

            final stats = snapshot.data ?? AiUsageMonthStats.empty;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Utilizzo AI del mese',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 6),
                Text(
                  'Totali mensili registrati dal server per le chiamate AI '
                  'dell\'app, in linea con il conteggio di usage.',
                  style: TextStyle(color: Colors.grey.shade700, height: 1.4),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _UsageStatChip(
                      label: 'Richieste',
                      value: '${stats.calls}',
                    ),
                    _UsageStatChip(
                      label: 'Token input',
                      value: _formatInt(stats.inputTokens),
                    ),
                    _UsageStatChip(
                      label: 'Token output',
                      value: _formatInt(stats.outputTokens),
                    ),
                    _UsageStatChip(
                      label: 'Token totali',
                      value: _formatInt(stats.totalTokens),
                    ),
                    _UsageStatChip(
                      label: 'Costo stimato',
                      value: EuroFormat.format(stats.estimatedEur),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _UsageStatChip extends StatelessWidget {
  const _UsageStatChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 150),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

String _formatInt(int value) {
  final text = value.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < text.length; i++) {
    final fromEnd = text.length - i;
    if (i > 0 && fromEnd % 3 == 0) {
      buffer.write('.');
    }
    buffer.write(text[i]);
  }
  return buffer.toString();
}
