// ignore_for_file: deprecated_member_use
// ============================================================
// CONFIG / IMPORT
// ============================================================

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:credit_calc_core/credit_calc_core.dart';
import '../../services/read_state_service.dart';
import '../../services/roleplay_progress_service.dart';
import '../../services/roleplay_conversation_service.dart';
import 'personal_form_shell.dart';

class RoleplayPage extends StatefulWidget {
  const RoleplayPage({super.key});

  @override
  State<RoleplayPage> createState() => _RoleplayPageState();
}

class _RoleplayPageState extends State<RoleplayPage> {
  int _tabIndex = 0;
  int _lastSeen = 0;
  bool _readStateReady = false;

  final SpeechToText _speech = SpeechToText();
  final FlutterTts _tts = FlutterTts();
  bool _speechReady = false;
  String? _speechLocaleId;

  String _lastUserText = '';
  String? _sessionId;
  bool _awaitingReply = false;
  bool _micListening = false;
  String? _responderRole;
  int _micRestartToken = 0;
  bool _startingListen = false;

  bool _simulationActive = false;
  bool _isSpeaking = false;
  bool? _ttsVoiceMale;
  bool _ttsReady = false;

  Map<String, dynamic>? _currentSimulation;
  String? _currentSimulationId;
  String? _currentSimulationCategory;

  final List<Map<String, String>> _chatHistory = [];

  @override
  void initState() {
    super.initState();
    _initReadState();
    _initSpeech();
  }

  bool get _shouldKeepListening =>
      _simulationActive && !_isSpeaking && !_awaitingReply;
  bool _isBenignSpeechError(String msg) =>
      msg == 'error_no_match' ||
      msg == 'error_speech_timeout' ||
      msg == 'error_client';

  Future<String?> _resolveItalianLocale() async {
    final locales = await _speech.locales();
    for (final locale in locales) {
      final id = locale.localeId.toLowerCase();
      if (id == 'it_it' || id == 'it-it' || id.startsWith('it')) {
        return locale.localeId;
      }
    }
    return null;
  }

  void _runAfterSpeechEvent(VoidCallback action) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      try {
        action();
      } catch (e, st) {
        debugPrint('Speech handler error: $e\n$st');
      }
    });
  }

  Future<void> _initSpeech() async {
    _speechReady = await _speech.initialize(
      onStatus: (status) {
        if (kDebugMode && status == 'listening') {
          debugPrint('Speech status: $status');
        }
        _runAfterSpeechEvent(() => _handleSpeechStatus(status));
      },
      onError: (error) {
        if (!_isBenignSpeechError(error.errorMsg)) {
          debugPrint('Speech error: $error');
        }
        _runAfterSpeechEvent(() => _handleSpeechError(error));
      },
    );
    if (_speechReady) {
      _speechLocaleId = await _resolveItalianLocale();
    }
    await _configureTtsVoice(preferMale: true);
  }

  void _handleSpeechStatus(String status) {
    if (!mounted) return;

    if (status == 'listening') {
      if (!_micListening && mounted) {
        setState(() => _micListening = true);
      }
      return;
    }

    if (status == 'done' || status == 'notListening') {
      if (_micListening && mounted) {
        setState(() => _micListening = false);
      }
      if (_shouldKeepListening) {
        _scheduleContinuousListening();
      }
    }
  }

  void _handleSpeechError(SpeechRecognitionError error) {
    if (!mounted) return;

    final benign = _isBenignSpeechError(error.errorMsg);

    if (benign && _shouldKeepListening) {
      _scheduleContinuousListening();
      return;
    }

    if (_shouldKeepListening) {
      _scheduleContinuousListening(delay: const Duration(milliseconds: 600));
    }
  }

  Future<void> _configureTtsVoice({required bool preferMale}) async {
    if (_ttsReady && _ttsVoiceMale == preferMale) return;

    await _tts.setLanguage('it-IT');
    await _tts.setSpeechRate(0.52);
    await _tts.setPitch(preferMale ? 0.78 : 1.0);

    final voices = await _tts.getVoices;
    if (voices is List) {
      Map<String, String>? italian;
      Map<String, String>? maleItalian;

      for (final raw in voices) {
        if (raw is! Map) continue;
        final voice = Map<String, String>.from(
          raw.map((k, v) => MapEntry(k.toString(), v.toString())),
        );
        final locale = (voice['locale'] ?? '').toLowerCase();
        final name = (voice['name'] ?? '').toLowerCase();
        if (!locale.contains('it')) continue;

        italian ??= voice;
        if (name.contains('male') ||
            name.contains('luca') ||
            name.contains('diego') ||
            name.contains('cosimo') ||
            name.contains('matteo') ||
            name.contains('it-it-x-itd')) {
          maleItalian = voice;
          break;
        }
      }

      final chosen = preferMale ? (maleItalian ?? italian) : italian;
      if (chosen != null) {
        await _tts.setVoice(chosen);
      }
    }

    _ttsVoiceMale = preferMale;
    _ttsReady = true;
  }

  Map<String, dynamic> _conversationPayload({required String userText}) {
    return {
      'userText': userText,
      'history': _chatHistory,
      'practiceData': _currentSimulation?['practiceData'] ?? [],
      'sessionId': _sessionId ?? 'default',
      'prompt': RoleplayConfigService.resolveSimulationPrompt(
        Map<String, dynamic>.from(_currentSimulation ?? const {}),
      ),
      if (_currentSimulation?['scenarioWeights'] != null)
        'scenarioWeights': _currentSimulation!['scenarioWeights'],
      if (_responderRole != null) 'responderRole': _responderRole,
      'difficulty': RoleplayConfigService.resolveDifficulty(
        Map<String, dynamic>.from(_currentSimulation ?? const {}),
      ),
      'personality': RoleplayConfigService.resolvePersonality(
        Map<String, dynamic>.from(_currentSimulation ?? const {}),
      ),
    };
  }

  Future<void> _requestRoleplayReply({required String userText}) async {
    if (!_simulationActive || _currentSimulation == null) return;

    setState(() => _awaitingReply = true);

    try {
      unawaited(_speech.stop().catchError((_) {}));
      if (mounted) setState(() => _micListening = false);

      final payload = _conversationPayload(userText: userText);
      final priorHistory = userText.isEmpty
          ? _chatHistory
              .map((m) => {
                    'role': m['role'] ?? 'user',
                    'content': m['content'] ?? '',
                  })
              .toList()
          : _chatHistory
              .where((m) =>
                  m['role'] != 'user' || m['content'] != userText)
              .map((m) => {
                    'role': m['role'] ?? 'user',
                    'content': m['content'] ?? '',
                  })
              .toList();

      final result = await RoleplayConversationService.step(
        userText: userText,
        prompt: payload['prompt'] as String,
        sessionId: payload['sessionId'] as String,
        history: priorHistory,
        practiceData: payload['practiceData'] as List<dynamic>,
        scenarioWeights: payload['scenarioWeights'] as Map<String, dynamic>?,
        responderRole: payload['responderRole'] as String?,
        difficulty: payload['difficulty'] as String?,
        personality: payload['personality'] as String?,
      );

      if (!mounted || !_simulationActive) return;

      final reply = (result['reply'] ?? '').toString().trim();
      if (result['role'] != null) {
        _responderRole = result['role'].toString();
      }

      if (reply.isNotEmpty) {
        _chatHistory.add({'role': 'assistant', 'content': reply});
        if (mounted) setState(() {});
        await _speak(reply);
      } else if (_simulationActive && mounted) {
        _scheduleContinuousListening();
      }
    } catch (e, st) {
      debugPrint('Roleplay step error: $e\n$st');
      if (mounted && _simulationActive) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Errore nella simulazione. Riprova a parlare.\n$e',
            ),
          ),
        );
        _scheduleContinuousListening();
      }
    } finally {
      if (mounted) setState(() => _awaitingReply = false);
    }
  }

  void _cancelMicRestart() {
    _micRestartToken++;
  }

  Future<void> _handleUserTranscript(SpeechRecognitionResult result) async {
    if (!result.finalResult || !_simulationActive || _awaitingReply) return;
    final transcript = result.recognizedWords.trim();
    if (transcript.isEmpty || transcript == _lastUserText) return;

    _lastUserText = transcript;
    _cancelMicRestart();

    _chatHistory.add({
      'role': 'user',
      'content': transcript,
    });

    if (!mounted || !_simulationActive) return;
    await _requestRoleplayReply(userText: transcript);
  }

  void _scheduleContinuousListening({
    Duration delay = const Duration(milliseconds: 80),
  }) {
    if (!_shouldKeepListening) return;
    final token = ++_micRestartToken;
    Future.delayed(delay, () async {
      if (token != _micRestartToken || !_shouldKeepListening) return;
      await _startListeningOnce();
      if (!mounted || !_shouldKeepListening) return;
      if (!_speech.isListening) {
        _scheduleContinuousListening(delay: const Duration(milliseconds: 300));
      }
    });
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
    _tts.stop();
    super.dispose();
  }

  void _stopSpeech() {
    _cancelMicRestart();
    try {
      _speech.stop();
    } catch (_) {}
  }

  Future<void> _startListeningOnce() async {
    if (!_speechReady || !_shouldKeepListening || _startingListen) return;
    if (_speech.isListening) return;

    _startingListen = true;
    try {
      try {
        await _speech.stop();
      } catch (_) {}
      await Future<void>.delayed(const Duration(milliseconds: 50));

      if (!_shouldKeepListening || !mounted) return;

      await _speech.listen(
        listenOptions: SpeechListenOptions(
          localeId: _speechLocaleId,
          listenMode: ListenMode.dictation,
          listenFor: const Duration(minutes: 30),
          pauseFor: const Duration(seconds: 3),
          cancelOnError: false,
          partialResults: true,
        ),
        onResult: (result) {
          unawaited(_handleUserTranscript(result));
        },
      );
    } catch (e) {
      debugPrint('Speech listen error: $e');
      if (_shouldKeepListening) {
        _scheduleContinuousListening(delay: const Duration(milliseconds: 900));
      }
    } finally {
      _startingListen = false;
    }
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

    _currentSimulation = simulationData;
    _currentSimulationId = simulationId;
    _currentSimulationCategory = category;
    _chatHistory.clear();
    _lastUserText = '';
    _sessionId = '${simulationId}_${DateTime.now().millisecondsSinceEpoch}';
    _awaitingReply = false;
    _micListening = false;
    _responderRole = null;

    _simulationActive = true;
    setState(() {});

    _stopSpeech();
    if (!_speechReady) {
      await _initSpeech();
    }

    await _requestRoleplayReply(userText: '');
  }

  Future<void> _stopSimulation() async {
    if (_simulationActive && _currentSimulation != null) {
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

    _simulationActive = false;
    _currentSimulation = null;
    _currentSimulationId = null;
    _currentSimulationCategory = null;

    _stopSpeech();
    _tts.stop();
    _isSpeaking = false;
    _micListening = false;
    setState(() {});
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

  Future<void> _speak(String text) async {
    _cancelMicRestart();
    _isSpeaking = true;
    if (mounted) setState(() => _micListening = false);
    try {
      unawaited(_speech.stop().catchError((_) {}));
      await _tts.stop();

      final role = (_responderRole ?? '').toUpperCase();
      final preferMale = role != 'TERZO';
      await _configureTtsVoice(preferMale: preferMale);

      await _tts.awaitSpeakCompletion(true);
      _tts.setCompletionHandler(() {
        _isSpeaking = false;
        if (_simulationActive && mounted) {
          _scheduleContinuousListening();
        }
      });
      await _tts.speak(text);
    } catch (e, st) {
      debugPrint('TTS error: $e\n$st');
      _isSpeaking = false;
      if (_simulationActive && mounted) {
        _scheduleContinuousListening();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final category = _tabIndex == 0 ? 'Sollecito' : 'Recupero';

    return PersonalFormShell(
      pageTitle: 'Role Play',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_simulationActive) ...[
            Material(
              color: const Color(0xFF1B5E20),
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      _awaitingReply
                          ? 'Il debitore sta pensando...'
                          : _isSpeaking
                              ? 'Il debitore parla...'
                              : 'Chiamata attiva — parla liberamente',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      height: 72,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _awaitingReply || _isSpeaking
                            ? Colors.grey.shade600
                            : const Color(0xFF1B5E20),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _awaitingReply || _isSpeaking
                                ? Icons.phone_in_talk_outlined
                                : Icons.phone_callback_outlined,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _awaitingReply
                                ? 'In attesa risposta'
                                : _isSpeaking
                                    ? 'Linea occupata'
                                    : 'Linea aperta',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
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
              simulationActive: _simulationActive,
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