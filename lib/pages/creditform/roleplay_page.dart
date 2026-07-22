// ignore_for_file: deprecated_member_use
// ============================================================
// CONFIG / IMPORT
// ============================================================

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:credit_calc_core/credit_calc_core.dart' hide AppCardTheme;
import '../../core/theme/app_card_theme.dart';
import '../../services/read_state_service.dart';
import '../../services/roleplay_progress_service.dart';
import '../../services/roleplay_session.dart';
import '../../services/roleplay_session_factory.dart';
import '../../services/roleplay_voice_status.dart';
import '../../widgets/roleplay_call_overlay.dart';
import '../../utils/roleplay_practice_data.dart';
import 'personal_form_shell.dart';
import 'personal_form_menu.dart';
import 'roleplay_results_page.dart';

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

  Map<String, RoleplaySimulationDetail> _simulationDetails = {};
  StreamSubscription<Map<String, RoleplaySimulationDetail>>? _detailsSub;

  @override
  void initState() {
    super.initState();
    _initReadState();
    _detailsSub = RoleplayProgressService.watchSimulationDetails().listen((map) {
      if (!mounted) return;
      setState(() => _simulationDetails = map);
    });
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
    _detailsSub?.cancel();
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
          history: List<Map<String, String>>.from(_chatHistory),
        );
      }
    }

    _currentSimulation = null;
    _currentSimulationId = null;
    _currentSimulationCategory = null;

    await _session?.stop();
    if (mounted) setState(() {});
  }

  Future<void> _openResults({
    required String simulationId,
    required String title,
    required Map<String, dynamic> simulationData,
    required VoidCallback onRestartCall,
    int initialTabIndex = 0,
  }) async {
    if (!mounted) return;
    final restart = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => RoleplayResultsPage(
          simulationId: simulationId,
          title: title,
          simulationData: simulationData,
          initialTabIndex: initialTabIndex,
        ),
      ),
    );
    if (restart == true && mounted) {
      onRestartCall();
    }
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
            final practiceData = RoleplayPracticeData.normalize(
              data['practiceData'] as List<dynamic>? ?? [],
            );
            final difficulty =
                RoleplayConfigService.resolveDifficulty(data);
            final personality =
                RoleplayConfigService.resolvePersonality(data);

            final createdAt = data['date'];
            int? millis;
            if (createdAt is String) {
              millis = DateTime.tryParse(createdAt)?.millisecondsSinceEpoch;
            } else if (createdAt is Timestamp) {
              millis = createdAt.millisecondsSinceEpoch;
            }
            final isNew =
                _readStateReady && millis != null && millis > _lastSeen;

            final simulationPayload = {
              'title': title,
              'prompt': data['prompt'] ?? '',
              'gptPrompt': data['gptPrompt'] ?? '',
              'practiceData': practiceData,
              'scenarioWeights':
                  data['scenarioWeights'] as Map<String, dynamic>?,
              'difficulty': data['difficulty'] ?? '',
              'personality': data['personality'] ?? '',
              'aiProvider': data[RoleplayConfigService.aiProviderField],
            };

            return _RoleplaySimulationCard(
              title: title,
              practiceData: practiceData,
              difficulty: difficulty,
              personality: personality,
              isNew: isNew,
              completed: _simulationDetails[doc.id]?.hasConversation == true,
              simulationActive: _isSimulationActive,
              detail: _simulationDetails[doc.id],
              onOpenSimulation: () => _startSimulation(
                simulationPayload,
                simulationId: doc.id,
                category: type,
              ),
              onStopSimulation: () => _stopSimulation(),
              onShowHint: () => _openResults(
                simulationId: doc.id,
                title: title,
                simulationData: simulationPayload,
                initialTabIndex: 1,
                onRestartCall: () => _startSimulation(
                  simulationPayload,
                  simulationId: doc.id,
                  category: type,
                ),
              ),
              onReplay: () => _openResults(
                simulationId: doc.id,
                title: title,
                simulationData: simulationPayload,
                initialTabIndex: 0,
                onRestartCall: () => _startSimulation(
                  simulationPayload,
                  simulationId: doc.id,
                  category: type,
                ),
              ),
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
  final RoleplaySimulationDetail? detail;
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
    required this.detail,
    required this.onOpenSimulation,
    required this.onStopSimulation,
    required this.onShowHint,
    required this.onReplay,
  });

  @override
  Widget build(BuildContext context) {
    final canOpenSuggestion = detail?.hasConversation == true;
    final canReplay = detail?.hasConversation == true;

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
          if (detail != null &&
              (detail!.hasConversation || detail!.hasSuggestion)) ...[
            const SizedBox(height: 12),
            if (detail!.hasConversation)
              _expandablePreviewCard(
                context: context,
                title: detail!.conversationAt == null
                    ? 'Ultima conversazione'
                    : 'Ultima conversazione · ${RoleplaySimulationDetail.formatDateTime(detail!.conversationAt!)}',
                preview: detail!.formatHistoryPreview(),
                fullText: detail!.history
                    .map((m) {
                      final who =
                          m['role'] == 'user' ? 'Consulente' : 'Debitore';
                      return '$who: ${m['content'] ?? ''}';
                    })
                    .join('\n\n'),
              ),
            if (detail!.hasSuggestion) ...[
              if (detail!.hasConversation) const SizedBox(height: 8),
              _expandablePreviewCard(
                context: context,
                title: detail!.evaluatedAt == null
                    ? 'Ultima valutazione AI'
                    : 'Ultima valutazione AI · ${RoleplaySimulationDetail.formatDateTime(detail!.evaluatedAt!)}',
                preview: detail!.formatSuggestionPreview(),
                fullText: detail!.suggestion ?? '',
              ),
            ],
          ],
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 12),
          _actionButton(
            label: 'Vedi suggerimento AI',
            enabled: canOpenSuggestion,
            onPressed: onShowHint,
          ),
          const SizedBox(height: 8),
          _actionButton(
            label: 'Conversazione / Leggi',
            enabled: canReplay,
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

  Widget _expandablePreviewCard({
    required BuildContext context,
    required String title,
    required String preview,
    required String fullText,
  }) {
    final needsExpand = fullText.trim().length > preview.trim().length;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 12),
          childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          title: Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              preview,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                height: 1.35,
                color: Colors.grey.shade800,
              ),
            ),
          ),
          trailing: needsExpand ? null : const SizedBox.shrink(),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                fullText,
                style: const TextStyle(fontSize: 13, height: 1.45),
              ),
            ),
          ],
        ),
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
          style: TextStyle(
            color: enabled ? Colors.black87 : Colors.black38,
          ),
        ),
      ),
    );
  }
}