// ignore_for_file: deprecated_member_use
// ============================================================
// CONFIG / IMPORT
// ============================================================

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/read_state_service.dart';
import '../../ui/layout/page_shell.dart';

class RoleplayPage extends StatefulWidget {
  const RoleplayPage({super.key});

  @override
  State<RoleplayPage> createState() => _RoleplayPageState();
}

class _RoleplayPageState extends State<RoleplayPage> {
  int _tabIndex = 0;
  int _lastSeen = 0;
  bool _readStateReady = false;

  WebSocketChannel? _channel;
  final SpeechToText _speech = SpeechToText();
  final FlutterTts _tts = FlutterTts();
  bool _speechReady = false;

  String _lastUserText = "";

  bool _simulationActive = false;
  bool _isSpeaking = false;

  Map<String, dynamic>? _currentSimulation;

  final List<Map<String, String>> _chatHistory = [];

  @override
  void initState() {
    super.initState();
    _initReadState();
    _initSpeech();
  }

  Future<void> _initSpeech() async {
    _speechReady = await _speech.initialize(
      onStatus: (status) => debugPrint('Speech status: $status'),
      onError: (error) => debugPrint('Speech error: $error'),
    );
    await _tts.setLanguage('it-IT');
    await _tts.setSpeechRate(0.45);
  }

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
    _stopSpeech();
    try {
      _channel?.sink.close();
    } catch (_) {}
    _tts.stop();
    super.dispose();
  }

  void _stopSpeech() {
    try {
      _speech.stop();
    } catch (_) {}
  }

  void _safeStartListening() {
    if (!_speechReady || !_simulationActive || _isSpeaking) return;
    _startListeningOnce();
  }

  Future<void> _startListeningOnce() async {
    if (!_speechReady || !_simulationActive || _isSpeaking) return;
    await _speech.listen(
      localeId: 'it_IT',
      listenMode: ListenMode.confirmation,
      onResult: (result) async {
        if (!result.finalResult || !_simulationActive) return;
        final transcript = result.recognizedWords.trim();
        if (transcript.isEmpty || transcript == _lastUserText) return;

        _lastUserText = transcript;
        await _speech.stop();
        _isSpeaking = false;

        _chatHistory.add({
          'role': 'user',
          'content': transcript,
        });

        if (!mounted || !_simulationActive) return;

        _channel?.sink.add(jsonEncode({
          'userText': transcript,
          'history': _chatHistory,
          'practiceData': _currentSimulation?['practiceData'] ?? [],
        }));
      },
    );
  }

  void _startSimulation(Map<String, dynamic> simulationData) {
    _currentSimulation = simulationData;
    _chatHistory.clear();
    _lastUserText = '';

    _simulationActive = true;
    setState(() {});

    _stopSpeech();

    try {
      _channel?.sink.close();
    } catch (_) {}

    _channel = WebSocketChannel.connect(
      Uri.parse('ws://162.55.210.130:3001'),
    );

    var aiBuffer = '';

    _channel!.stream.listen((event) {
      final msg = event.toString();

      if (msg == '[END]') {
        if (aiBuffer.trim().isNotEmpty) {
          _chatHistory.add({
            'role': 'assistant',
            'content': aiBuffer,
          });
          _speak(aiBuffer);
        }
        aiBuffer = '';
        return;
      }

      aiBuffer += msg;
    });

    Future.delayed(const Duration(milliseconds: 300), () {
      if (!_simulationActive) return;
      _channel?.sink.add(jsonEncode({
        'userText': '',
        'history': _chatHistory,
        'practiceData': simulationData['practiceData'] ?? [],
      }));
      _safeStartListening();
    });
  }

  void _stopSimulation() {
    _simulationActive = false;
    _stopSpeech();
    try {
      _channel?.sink.close();
    } catch (_) {}
    _tts.stop();
    _isSpeaking = false;
    setState(() {});
  }

  Future<void> _speak(String text) async {
    _isSpeaking = true;
    await _tts.stop();
    _tts.setCompletionHandler(() {
      _isSpeaking = false;
      if (_simulationActive) {
        Future.delayed(const Duration(milliseconds: 500), _safeStartListening);
      }
    });
    await _tts.speak(text);
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final category = _tabIndex == 0 ? 'Sollecito' : 'Recupero';

    return SecondaryPageScaffold(
      pageTitle: 'Roleplay',
      project: BrandedPageProject.form,
      body: Column(
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
          color: Colors.white,
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
              isNew: isNew,
              completed: completed,
              simulationActive: _simulationActive,
              onOpenSimulation: () => _startSimulation({
                'title': title,
                'prompt': data['prompt'] ?? '',
                'practiceData': practiceData,
              }),
              onStopSimulation: _stopSimulation,
              onShowHint: completed
                  ? () {
                      showDialog<void>(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: const Text('Suggerimento AI'),
                          content: const Text(
                            'Qui verrà mostrato il suggerimento generato '
                            "dall'intelligenza artificiale.",
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
                  : null,
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
  final bool isNew;
  final bool completed;
  final bool simulationActive;
  final VoidCallback onOpenSimulation;
  final VoidCallback onStopSimulation;
  final VoidCallback? onShowHint;

  const _RoleplaySimulationCard({
    required this.title,
    required this.practiceData,
    required this.isNew,
    required this.completed,
    required this.simulationActive,
    required this.onOpenSimulation,
    required this.onStopSimulation,
    this.onShowHint,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
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
            enabled: onShowHint != null,
            onPressed: onShowHint,
          ),
          const SizedBox(height: 8),
          _actionButton(
            label: 'Riascolta registrazione',
            enabled: false,
            onPressed: null,
          ),
          const SizedBox(height: 8),
          _actionButton(
            label: simulationActive ? 'Termina simulazione' : 'Avvia simulazione',
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