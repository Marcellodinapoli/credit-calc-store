import 'package:flutter/material.dart';

import '../../core/maintenance_service.dart';
import '../../services/normative_search_config_service.dart';
import '../../services/normative_search_service.dart';
import '../../ui/layout/page_shell.dart';
import '../../widgets/maintenance_section_gate.dart';

class _ChatTurn {
  final String role;
  final String content;

  const _ChatTurn({required this.role, required this.content});
}

/// Strumenti — domande su attività stragiudiziale e recupero crediti con risposta AI.
class NormativeSearchPage extends StatefulWidget {
  const NormativeSearchPage({super.key});

  @override
  State<NormativeSearchPage> createState() => _NormativeSearchPageState();
}

class _NormativeSearchPageState extends State<NormativeSearchPage> {
  final _questionCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _turns = <_ChatTurn>[];
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _questionCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final question = _questionCtrl.text.trim();
    if (question.isEmpty || _loading) return;

    setState(() {
      _loading = true;
      _error = null;
      _turns.add(_ChatTurn(role: 'user', content: question));
      _questionCtrl.clear();
    });
    _scrollToEnd();

    try {
      final prompt = await NormativeSearchConfigService.loadPrompt();
      final history = _turns
          .where((t) => t != _turns.last)
          .map((t) => {'role': t.role, 'content': t.content})
          .toList();
      final answer = await NormativeSearchService.ask(
        question: question,
        systemPrompt: prompt,
        history: history,
      );
      if (!mounted) return;
      setState(() {
        _turns.add(_ChatTurn(role: 'assistant', content: answer));
        _loading = false;
      });
      _scrollToEnd();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Impossibile ottenere una risposta. Riprova tra poco.';
        if (_turns.isNotEmpty && _turns.last.role == 'user') {
          _turns.removeLast();
        }
        _questionCtrl.text = question;
      });
    }
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollCtrl.hasClients) return;
      _scrollCtrl.animateTo(
        _scrollCtrl.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return SecondaryPageScaffold(
      pageTitle: 'Strumenti',
      project: BrandedPageProject.calc,
      body: MaintenanceSectionGate(
        sectionName: MaintenanceService.creditCalc,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Text(
                'Scrivi una domanda sull\'attività stragiudiziale, in particolare '
                'sul recupero crediti. L\'assistente risponde in linguaggio semplice.',
                style: TextStyle(color: Colors.grey.shade700, height: 1.45),
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Le risposte hanno scopo informativo e non sostituiscono il parere '
                'di un professionista qualificato.',
                style: TextStyle(
                  color: Colors.orange.shade800,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Text(
                  _error!,
                  style: TextStyle(color: Colors.red.shade700),
                ),
              ),
            Expanded(
              child: _turns.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'Scrivi la prima domanda nel campo in basso per iniziare.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollCtrl,
                      padding: const EdgeInsets.all(16),
                      itemCount: _turns.length + (_loading ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == _turns.length) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 20,
                                  height: 20,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                ),
                                SizedBox(width: 12),
                                Text('Analisi in corso…'),
                              ],
                            ),
                          );
                        }
                        final turn = _turns[index];
                        final isUser = turn.role == 'user';
                        return Align(
                          alignment: isUser
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            constraints: BoxConstraints(
                              maxWidth: MediaQuery.sizeOf(context).width * 0.85,
                            ),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: isUser
                                  ? const Color(0xFF00B0FF)
                                      .withValues(alpha: 0.12)
                                  : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isUser
                                    ? const Color(0xFF00B0FF)
                                        .withValues(alpha: 0.35)
                                    : Colors.grey.shade300,
                              ),
                            ),
                            child: Text(
                              turn.content,
                              style: const TextStyle(height: 1.45),
                            ),
                          ),
                        );
                      },
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _questionCtrl,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _submit(),
                      decoration: const InputDecoration(
                        hintText: 'Scrivi la tua domanda…',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _loading ? null : _submit,
                    child: const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
