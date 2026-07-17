// ignore_for_file: deprecated_member_use
// ============================================================
// CONFIG / IMPORT
// ============================================================

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:credit_calc_core/credit_calc_core.dart';
import '../../core/theme/app_card_theme.dart';
import '../../services/read_state_service.dart';
import '../../services/roleplay_progress_service.dart';
import '../../services/roleplay_conversation_service.dart';
import '../../services/roleplay_session.dart';
import '../../services/roleplay_session_factory.dart';
import '../../services/roleplay_voice_status.dart';
import '../../widgets/roleplay_call_overlay.dart';
import 'personal_form_shell.dart';
import 'personal_form_menu.dart';

class RoleplayPage extends StatefulWidget {
  const RoleplayPage({super.key});

  @override
  State<RoleplayPage> createState() => _RoleplayPageState();
}

class _RoleplayPageState extends State<RoleplayPage> {
  int _tabIndex = 0;
  int _lastSeen = 0;
  bool _readStateReady = false;

  RoleplaySession? _session;
  String? _sessionEngine;

  Map<String, dynamic>? _currentSimulation;
  String? _currentSimulationId;
  String? _currentSimulationCategory;

  @override
  void initState() {
    super.initState();
    _initReadState();
  }

  RoleplaySession _createSession(String engine) {
    return RoleplaySessionFactory.create(
      aiProvider: engine,
      onStateChanged: () {
        if (mounted) setState(() {});
      },
      onError: (message) {
      if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      },
      isContextActive: () => mounted,
    );
  }

  Future<void> _ensureSession(String engine) async {
    if (_session != null && _sessionEngine == engine) {
      return;
    }
    if (_session != null) {
      await _session!.stop();
      _session!.dispose();
      _session = null;
    }
    _session = _createSession(engine);
    _sessionEngine = engine;
    await _session!.init();
  }

  bool get _isSimulationActive => _session?.isActive ?? false;

  List<Map<String, String>> get _chatHistory =>
      _session?.history ?? const [];
  RoleplayVoiceStatus get _voiceStatus =>
      _session?.voiceStatus ?? RoleplayVoiceStatus.idle;

  Future<void> _initReadState() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final storedLastSeen = await ReadStateService.getRoleplayLastSeenMs();

    if (!mounted) return;

    if (storedLastSeen == 0) {
      await ReadStateService.ensureRoleplayInitialized(now);
      setState(() {
        _lastSeen = now;
        _readStateReady = true;
      });
      return;
    }

    setState(() {
      _lastSeen = storedLastSeen;
      _readStateReady = true;
    });
    ReadStateService.setRoleplayLastSeenMs(now);
  }

  @override
  void dispose() {
    if (_session != null) {
      unawaited(_session!.stop());
      _session!.dispose();
      _session = null;
    }
    super.dispose();
  }

  Future<void> _startSimulation(
    Map<String, dynamic> simulationData, {
    required String simulationId,
    required String category,
  }) async {
    if (!mounted) return;
    if (!await PublicUsageCounterRecorder.recordWithUi(
      context,
      PublicUsageMetric.roleplay,
    )) {
      return;
    }
    if (!mounted) return;

    final normalizedProvider =
        RoleplaySessionFactory.resolveProvider(simulationData);
    final engine = RoleplaySessionFactory.activeEngine(normalizedProvider);

    await _ensureSession(engine);

    _currentSimulation = simulationData;
    _currentSimulationId = simulationId;
    _currentSimulationCategory = category;

    setState(() {});

    final sessionId = '${simulationId}_${DateTime.now().millisecondsSinceEpoch}';
    await _session!.start(
      simulationData: simulationData,
      sessionId: sessionId,
    );
  }

  Future<void> _stopSimulation() async {
    if (_isSimulationActive && _currentSimulation != null) {
      final userExchanges =
          _chatHistory.where((m) => m['role'] == 'user').length;
      if (userExchanges > 0 || _chatHistory.isNotEmpty) {
        await RoleplayProgressService.saveLastSimulation(
          simulationId: _currentSimulationId ?? '',
          title: (_currentSimulation!['title'] ?? 'Simulazione').toString(),
          category: _currentSimulationCategory ?? '',
          practiceData:
              _currentSimulation!['practiceData'] as List<dynamic>? ?? [],
          userExchanges: userExchanges,
          totalMessages: _chatHistory.length,
        );
      }
    }

    _currentSimulation = null;
    _currentSimulationId = null;
    _currentSimulationCategory = null;

    await _session?.stop();
    if (mounted) setState(() {});
  }

  Future<void> _showAiSuggestion({
    required Map<String, dynamic> simulationData,
    required String title,
  }) async {
    if (_chatHistory.isEmpty) {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Suggerimento AI'),
          content: const Text(
            'Avvia e completa almeno uno scambio nella simulazione '
            'prima di richiedere il suggerimento.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Chiudi'),
            ),
          ],
        ),
      );
      return;
    }

    if (!mounted) return;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Expanded(child: Text('Generazione suggerimento…')),
          ],
        ),
      ),
    );

    try {
      final practiceData =
          simulationData['practiceData'] as List<dynamic>? ?? [];
      final practiceText = practiceData
          .whereType<Map>()
          .map((row) => '${row['label'] ?? ''}: ${row['value'] ?? ''}')
          .join('; ');

      final suggestion = await RoleplayConversationService.suggestion(
        prompt: RoleplayConfigService.resolveSimulationPrompt(simulationData),
        title: title,
        history: _chatHistory,
        practiceData: practiceData,
        practiceText: practiceText,
        difficulty: RoleplayConfigService.resolveDifficulty(simulationData),
        personality: RoleplayConfigService.resolvePersonality(simulationData),
      );

      if (!mounted) return;
      Navigator.pop(context);
      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Suggerimento AI'),
          content: SingleChildScrollView(child: Text(suggestion)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Chiudi'),
            ),
          ],
        ),
      );
    } catch (_) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Impossibile generare il suggerimento. Riprova.'),
        ),
      );
    }
  }

  Future<void> _showRecordingReplay() async {
    if (_chatHistory.isEmpty) {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Riascolta registrazione'),
          content: const Text(
            'Avvia e termina una simulazione prima di riascoltare '
            'la registrazione.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Chiudi'),
            ),
          ],
        ),
      );
      return;
    }

    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Riascolta registrazione'),
        content: SingleChildScrollView(
          child: Text(
            _chatHistory
                .map((message) {
                  final who =
                      message['role'] == 'user' ? 'Consulente' : 'Debitore';
                  return '$who: ${message['content'] ?? ''}';
                })
                .join('\n\n'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Chiudi'),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final category = _tabIndex == 0 ? 'Sollecito' : 'Recupero';

    return PersonalFormShell(
      pageTitle: 'Role Play',
      showAccountMenu: true,
      activeMenuItem: PersonalFormMenuItem.roleplay,
      body: Stack(
        children: [
          Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: _tabButton('Sollecito', 0)),
              const SizedBox(width: 8),
              Expanded(child: _tabButton('Recupero', 1)),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(child: _buildSimulations(category)),
        ],
      ),
          if (_isSimulationActive && _currentSimulation != null)
            RoleplayCallOverlay(
              title: (_currentSimulation!['title'] ?? 'Simulazione').toString(),
              practiceData:
                  _currentSimulation!['practiceData'] as List<dynamic>? ?? [],
              voiceStatus: _voiceStatus,
              chatHistory: _chatHistory,
              onHangUp: _stopSimulation,
            ),
        ],
      ),
    );
  }

  Widget _tabButton(String label, int index) {
    final selected = _tabIndex == index;
    return Material(
      color: selected ? const Color(0xFFFFA726) : const Color(0xFFECEFF1),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => setState(() => _tabIndex = index),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: selected ? Colors.white : Colors.black87,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

// ============================================================
// UI HELPERS
// ============================================================

  Widget _buildLoadingPlaceholder() {
    return ListView.builder(
      padding: EdgeInsets.zero,
      itemCount: 2,
      itemBuilder: (_, __) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppCardTheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _skeletonBox(width: 200, height: 18),
            const SizedBox(height: 10),
            _skeletonBox(height: 12),
            _skeletonBox(height: 12, width: 180),
          ],
        ),
      ),
    );
  }

  Widget _skeletonBox({double? width, double height = 14}) {
    return Container(
      width: width,
      height: height,
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: Colors.grey.shade300,
        borderRadius: BorderRadius.circular(6),
      ),
    );
  }

  Widget _buildSimulations(String type) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('roleplay')
          .orderBy('date', descending: false)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return _buildLoadingPlaceholder();
        }
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Errore nel caricamento delle simulazioni\n${snapshot.error}',
                style: const TextStyle(color: Colors.red),
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        final docs = (snapshot.data?.docs ?? [])
            .where((d) => (d['category'] ?? '') == type)
            .toList();

        if (docs.isEmpty) {
          return const Center(
            child: Text(
              'Nessuna simulazione disponibile',
              style: TextStyle(color: Colors.black54, fontSize: 15),
            ),
          );
        }

        return ListView.separated(
          padding: EdgeInsets.zero,
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;
            final title = (data['title'] ?? 'Simulazione').toString();
            final practiceData =
                (data['practiceData'] as List<dynamic>? ?? []);
            final difficulty =
                RoleplayConfigService.resolveDifficulty(data);
            final personality =
                RoleplayConfigService.resolvePersonality(data);
            final completed = data['completed'] == true;

            final createdAt = data['date'];
            int? millis;
            if (createdAt is String) {
              millis = DateTime.tryParse(createdAt)?.millisecondsSinceEpoch;
            } else if (createdAt is Timestamp) {
              millis = createdAt.millisecondsSinceEpoch;
            }
            final isNew =
                _readStateReady && millis != null && millis > _lastSeen;

            return _RoleplaySimulationCard(
              title: title,
              practiceData: practiceData,
              difficulty: difficulty,
              personality: personality,
              isNew: isNew,
              completed: completed,
              simulationActive: _isSimulationActive,
              onOpenSimulation: () => _startSimulation(
                {
                  'title': title,
                  'prompt': data['prompt'] ?? '',
                  'gptPrompt': data['gptPrompt'] ?? '',
                  'practiceData': practiceData,
                  'scenarioWeights':
                      data['scenarioWeights'] as Map<String, dynamic>?,
                  'difficulty': data['difficulty'] ?? '',
                  'personality': data['personality'] ?? '',
                  'aiProvider': data[RoleplayConfigService.aiProviderField],
                },
                simulationId: doc.id,
                category: type,
              ),
              onStopSimulation: () => _stopSimulation(),
              onShowHint: () => _showAiSuggestion(
                simulationData: {
                  'title': title,
                  'prompt': data['prompt'] ?? '',
                  'gptPrompt': data['gptPrompt'] ?? '',
                  'practiceData': practiceData,
                  'scenarioWeights':
                      data['scenarioWeights'] as Map<String, dynamic>?,
                  'difficulty': data['difficulty'] ?? '',
                  'personality': data['personality'] ?? '',
                },
                title: title,
              ),
              onReplay: _showRecordingReplay,
            );
          },
        );
      },
    );
  }
}

class _RoleplaySimulationCard extends StatelessWidget {
  final String title;
  final List<dynamic> practiceData;
  final String difficulty;
  final String personality;
  final bool isNew;
  final bool completed;
  final bool simulationActive;
  final VoidCallback onOpenSimulation;
  final VoidCallback onStopSimulation;
  final VoidCallback onShowHint;
  final VoidCallback onReplay;

  const _RoleplaySimulationCard({
    required this.title,
    required this.practiceData,
    required this.difficulty,
    required this.personality,
    required this.isNew,
    required this.completed,
    required this.simulationActive,
    required this.onOpenSimulation,
    required this.onStopSimulation,
    required this.onShowHint,
    required this.onReplay,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppCardTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 17,
                    color: Colors.black,
                  ),
                ),
              ),
              if (isNew)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.redAccent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    'NEW',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Difficoltà: ${RoleplayConfigService.difficultyLabel(difficulty)}'
            ' · Personalità: ${RoleplayConfigService.personalityLabel(personality)}',
            style: const TextStyle(
              fontSize: 13,
              color: Colors.black54,
              height: 1.4,
            ),
          ),
          if (practiceData.isNotEmpty) ...[
            const SizedBox(height: 12),
            for (final item in practiceData)
              if (item is Map) ...[
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: '${item['label'] ?? ''}: ',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                          fontSize: 14,
                          height: 1.4,
                        ),
                      ),
                      TextSpan(
                        text: '${item['value'] ?? ''}',
                        style: const TextStyle(
                          color: Colors.black87,
                          fontSize: 14,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
              ],
          ],
          const SizedBox(height: 8),
          const Text(
            'Valutazione automatica basata su intelligenza artificiale, '
            'a scopo formativo.',
            style: TextStyle(fontSize: 12, color: Colors.black54),
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 12),
          _actionButton(
            label: 'Vedi suggerimento AI',
            enabled: true,
            onPressed: onShowHint,
          ),
          const SizedBox(height: 8),
          _actionButton(
            label: 'Riascolta registrazione',
            enabled: true,
            onPressed: onReplay,
          ),
          const SizedBox(height: 8),
          _actionButton(
            label: simulationActive ? 'Termina chiamata' : 'Avvia chiamata',
            enabled: true,
            filled: true,
            onPressed: simulationActive ? onStopSimulation : onOpenSimulation,
          ),
        ],
      ),
    );
  }

  Widget _actionButton({
    required String label,
    required bool enabled,
    required VoidCallback? onPressed,
    bool filled = false,
  }) {
    if (filled) {
      return SizedBox(
        width: double.infinity,
        child: FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFFFA726),
            foregroundColor: Colors.white,
            disabledBackgroundColor: Colors.grey.shade300,
          ),
          onPressed: enabled ? onPressed : null,
          child: Text(label),
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.black87,
          side: const BorderSide(color: Colors.black54),
          disabledForegroundColor: Colors.black38,
        ),
        onPressed: enabled ? onPressed : null,
        child: Text(
          label,
          style: const TextStyle(color: Colors.black87),
        ),
      ),
    );
  }
}