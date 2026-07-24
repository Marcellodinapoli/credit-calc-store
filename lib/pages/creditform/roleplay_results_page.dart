import 'dart:async';

import 'package:credit_calc_core/credit_calc_core.dart' hide AppCardTheme;
import 'package:flutter/material.dart';

import '../../core/theme/app_card_theme.dart';
import '../../services/roleplay_conversation_service.dart';
import '../../services/roleplay_progress_service.dart';
import 'personal_form_shell.dart';

/// Secondo screen Role Play: tab Conversazione | Valutazione.
class RoleplayResultsPage extends StatefulWidget {
  const RoleplayResultsPage({
    super.key,
    required this.simulationId,
    required this.title,
    required this.simulationData,
    this.initialTabIndex = 0,
  });

  final String simulationId;
  final String title;
  final Map<String, dynamic> simulationData;
  final int initialTabIndex;

  @override
  State<RoleplayResultsPage> createState() => _RoleplayResultsPageState();
}

class _RoleplayResultsPageState extends State<RoleplayResultsPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  StreamSubscription<Map<String, RoleplaySimulationDetail>>? _detailsSub;
  RoleplaySimulationDetail? _detail;
  bool _generating = false;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialTabIndex.clamp(0, 1);
    _tabs = TabController(length: 2, vsync: this, initialIndex: initial);
    _detailsSub = RoleplayProgressService.watchSimulationDetails().listen((map) {
      if (!mounted) return;
      setState(() => _detail = map[widget.simulationId]);
    });
  }

  @override
  void dispose() {
    _detailsSub?.cancel();
    _tabs.dispose();
    super.dispose();
  }

  String get _sessionLabel {
    final d = _detail;
    if (d == null) return '';
    final at = d.conversationAt ?? d.evaluatedAt;
    if (at == null) return '';
    return RoleplaySimulationDetail.formatDateTime(at);
  }

  Future<void> _generateEvaluation() async {
    final history = _detail?.history ?? const <Map<String, String>>[];
    if (history.isEmpty || _generating) return;

    setState(() => _generating = true);
    try {
      final practiceData =
          widget.simulationData['practiceData'] as List<dynamic>? ?? [];
      final practiceText = practiceData
          .whereType<Map>()
          .map((row) => '${row['label'] ?? ''}: ${row['value'] ?? ''}')
          .join('; ');

      final suggestion = await RoleplayConversationService.suggestion(
        prompt: RoleplayConfigService.resolveSimulationPrompt(
          widget.simulationData,
        ),
        title: widget.title,
        history: history,
        practiceData: practiceData,
        practiceText: practiceText,
        difficulty: RoleplayConfigService.resolveDifficulty(
          widget.simulationData,
        ),
        personality: RoleplayConfigService.resolvePersonality(
          widget.simulationData,
        ),
      );

      await RoleplayProgressService.saveSimulationSuggestion(
        simulationId: widget.simulationId,
        suggestion: suggestion,
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Impossibile generare la valutazione. Riprova.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = _sessionLabel;

    return PersonalFormShell(
      pageTitle: 'Risultati',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 17,
              color: Colors.black,
            ),
          ),
          if (session.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Ultima sessione · $session',
              style: const TextStyle(fontSize: 13, color: Colors.black54),
            ),
          ],
          const SizedBox(height: 12),
          Material(
            color: AppCardTheme.surface,
            borderRadius: BorderRadius.circular(10),
            child: TabBar(
              controller: _tabs,
              labelColor: Colors.black87,
              unselectedLabelColor: Colors.black45,
              indicatorColor: const Color(0xFFFFA726),
              tabs: const [
                Tab(text: 'Conversazione'),
                Tab(text: 'Valutazione'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                _ConversationTab(detail: _detail),
                _EvaluationTab(
                  detail: _detail,
                  generating: _generating,
                  onGenerate: _generateEvaluation,
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFFFA726),
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(context),
              child: const Text('Torna al Role Play'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConversationTab extends StatelessWidget {
  const _ConversationTab({required this.detail});

  final RoleplaySimulationDetail? detail;

  @override
  Widget build(BuildContext context) {
    final history = detail?.history ?? const [];
    if (history.isEmpty) {
      return const _EmptyPanel(
        message:
            'Nessuna conversazione salvata. Avvia e termina una chiamata '
            'per vedere la trascrizione qui.',
      );
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppCardTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: history.length,
        separatorBuilder: (_, __) => const SizedBox(height: 14),
        itemBuilder: (context, index) {
          final message = history[index];
          final isUser = message['role'] == 'user';
          final who = isUser ? 'Consulente' : 'Debitore';
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                who,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isUser ? const Color(0xFFE65100) : Colors.black54,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                message['content'] ?? '',
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.45,
                  color: Colors.black87,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _EvaluationTab extends StatelessWidget {
  const _EvaluationTab({
    required this.detail,
    required this.generating,
    required this.onGenerate,
  });

  final RoleplaySimulationDetail? detail;
  final bool generating;
  final VoidCallback onGenerate;

  @override
  Widget build(BuildContext context) {
    if (detail?.hasSuggestion == true) {
      final evaluated = detail!.evaluatedAt;
      return Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppCardTheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (evaluated != null) ...[
              Text(
                'Valutazione · ${RoleplaySimulationDetail.formatDateTime(evaluated)}',
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
              const SizedBox(height: 12),
            ],
            Text(
              detail!.suggestion ?? '',
              style: const TextStyle(
                fontSize: 14,
                height: 1.45,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      );
    }

    if (detail?.hasConversation != true) {
      return const _EmptyPanel(
        message:
            'Nessuna valutazione disponibile. Completa prima una conversazione.',
      );
    }

    return _EmptyPanel(
      message:
          'Hai una conversazione salvata. Genera la valutazione AI per '
          'vedere punteggio e feedback.',
      action: SizedBox(
        width: double.infinity,
        child: OutlinedButton(
          onPressed: generating ? null : onGenerate,
          child: generating
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Genera valutazione AI'),
        ),
      ),
    );
  }
}

class _EmptyPanel extends StatelessWidget {
  const _EmptyPanel({required this.message, this.action});

  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message,
            style: const TextStyle(
              fontSize: 14,
              height: 1.45,
              color: Colors.black54,
            ),
          ),
          if (action != null) ...[
            const SizedBox(height: 16),
            action!,
          ],
        ],
      ),
    );
  }
}
