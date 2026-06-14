// ignore_for_file: deprecated_member_use
// ============================================================
// CONFIG / IMPORT
// ============================================================

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/read_state_service.dart';
import '../../services/roleplay_progress_service.dart';
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

  WebSocketChannel? _channel;
  SpeechToText _speech = SpeechToText();
  final FlutterTts _tts = FlutterTts();
  bool _speechReady = false;
  String? _speechLocaleId;

  String _lastUserText = '';
  String? _sessionId;
  bool _awaitingReply = false;
  bool _needsMicTap = false;
  bool _micActive = false;
  String? _responderRole;
  int _micRestartToken = 0;
  bool _startingListen = false;

  static const String _metaPrefix = '__META__:';

  bool _simulationActive = false;
  bool _isSpeaking = false;

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
      if (!_micActive || _needsMicTap) {
        setState(() {
          _micActive = true;
          _needsMicTap = false;
        });
      }
      return;
    }

    if (status == 'done' || status == 'notListening') {
      if (_shouldKeepListening) {
        if (!_micActive || _needsMicTap) {
          setState(() {
            _micActive = true;
            _needsMicTap = false;
          });
        }
        _scheduleContinuousListening();
      } else if (_micActive) {
        setState(() => _micActive = false);
      }
    }
  }

  void _handleSpeechError(SpeechRecognitionError error) {
    if (!mounted) return;

    final benign = _isBenignSpeechError(error.errorMsg);

    if (benign && _shouldKeepListening) {
      if (!_micActive) {
        setState(() => _micActive = true);
      }
      _scheduleContinuousListening();
      return;
    }

    if (_micActive) setState(() => _micActive = false);

    if (_shouldKeepListening) {
      _scheduleContinuousListening(delay: const Duration(milliseconds: 1200));
    } else {
      setState(() => _needsMicTap = true);
    }
  }

  Future<void> _configureTtsVoice({required bool preferMale}) async {
    await _tts.setLanguage('it-IT');
    await _tts.setSpeechRate(0.48);
    await _tts.setPitch(preferMale ? 0.78 : 1.0);

    final voices = await _tts.getVoices;
    if (voices is! List) return;

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

  String _extractSpeakableReply(String raw) {
    var trimmed = raw.trim();
    if (trimmed.isEmpty) return trimmed;

    final metaIdx = trimmed.indexOf(_metaPrefix);
    if (metaIdx >= 0) {
      trimmed = trimmed.substring(0, metaIdx).trim();
    }

    if (!trimmed.startsWith('{')) return trimmed;

    try {
      final parsed = jsonDecode(trimmed);
      if (parsed is Map && parsed['reply'] != null) {
        if (parsed['role'] != null) {
          _responderRole = parsed['role'].toString();
        }
        return parsed['reply'].toString().trim();
      }
    } catch (_) {}

    return trimmed;
  }

  Map<String, dynamic> _wsPayload({required String userText}) {
    return {
      'userText': userText,
      'history': _chatHistory,
      'practiceData': _currentSimulation?['practiceData'] ?? [],
      'sessionId': _sessionId ?? 'default',
      'prompt': (_currentSimulation?['prompt'] ?? '').toString(),
      'supportsMeta': true,
      if (_currentSimulation?['scenarioWeights'] != null)
        'scenarioWeights': _currentSimulation!['scenarioWeights'],
    };
  }

  void _cancelMicRestart() {
    _micRestartToken++;
  }

  void _requestMicrophone() {
    if (!_simulationActive || _isSpeaking || _awaitingReply) return;
    _cancelMicRestart();
    setState(() => _needsMicTap = false);
    _safeStartListening();
  }

  void _scheduleContinuousListening({
    Duration delay = const Duration(milliseconds: 450),
  }) {
    if (!_shouldKeepListening) return;
    final token = ++_micRestartToken;
    Future.delayed(delay, () async {
      if (token != _micRestartToken || !_shouldKeepListening) return;
      await _startListeningOnce();
      if (!mounted || !_shouldKeepListening) return;
      if (!_speech.isListening) {
        _scheduleContinuousListening(delay: const Duration(milliseconds: 900));
      }
    });
  }

  void _scheduleMicRestart() => _scheduleContinuousListening(
        delay: const Duration(milliseconds: 1200),
      );

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
    _cancelMicRestart();
    try {
      _speech.stop();
    } catch (_) {}
  }

  Future<void> _refreshSpeechEngine() async {
    _cancelMicRestart();
    try {
      await _speech.stop();
    } catch (_) {}
    _speech = SpeechToText();
    _speechReady = false;
    _speechLocaleId = null;
    await _initSpeech();
  }

  void _safeStartListening() {
    unawaited(_startListeningOnce());
  }

  Future<void> _startListeningOnce() async {
    if (!_speechReady || !_shouldKeepListening || _startingListen) return;
    if (_speech.isListening) return;

    _startingListen = true;
    try {
      try {
        await _speech.stop();
      } catch (_) {}
      await Future<void>.delayed(const Duration(milliseconds: 150));

      if (!_shouldKeepListening || !mounted) return;

      await _speech.listen(
        listenOptions: SpeechListenOptions(
          localeId: _speechLocaleId,
          listenMode: ListenMode.dictation,
          listenFor: const Duration(seconds: 120),
          pauseFor: const Duration(seconds: 4),
          cancelOnError: true,
          partialResults: true,
        ),
        onResult: (result) {
          unawaited(_handleUserTranscript(result));
        },
      );
      if (mounted) {
        setState(() {
          _needsMicTap = false;
          _micActive = true;
        });
      }
    } catch (e) {
      debugPrint('Speech listen error: $e');
      if (_shouldKeepListening) {
        _scheduleContinuousListening(delay: const Duration(milliseconds: 900));
      } else if (mounted) {
        setState(() => _needsMicTap = true);
      }
    } finally {
      _startingListen = false;
    }
  }

  Future<void> _handleUserTranscript(SpeechRecognitionResult result) async {
    if (!result.finalResult || !_simulationActive) return;
    final transcript = result.recognizedWords.trim();
    if (transcript.isEmpty || transcript == _lastUserText) return;

    _lastUserText = transcript;
    _cancelMicRestart();

    if (mounted) {
      setState(() {
        _awaitingReply = true;
        _micActive = false;
      });
    }

    try {
      await _speech.stop();
    } catch (_) {}

    _chatHistory.add({
      'role': 'user',
      'content': transcript,
    });

    if (!mounted || !_simulationActive) return;
    _channel?.sink.add(jsonEncode(_wsPayload(userText: transcript)));
  }

  void _startSimulation(
    Map<String, dynamic> simulationData, {
    required String simulationId,
    required String category,
  }) {
    _currentSimulation = simulationData;
    _currentSimulationId = simulationId;
    _currentSimulationCategory = category;
    _chatHistory.clear();
    _lastUserText = '';
    _sessionId = '${simulationId}_${DateTime.now().millisecondsSinceEpoch}';
    _awaitingReply = false;
    _needsMicTap = false;
    _micActive = false;
    _responderRole = null;

    _simulationActive = true;
    setState(() {});

    _stopSpeech();
    unawaited(_refreshSpeechEngine());

    try {
      _channel?.sink.close();
    } catch (_) {}

    _channel = WebSocketChannel.connect(
      Uri.parse('ws://162.55.210.130:3001'),
    );

    final aiBuffer = StringBuffer();

    _channel!.stream.listen((event) {
      final msg = event.toString();

      if (msg == '[END]') {
        final reply = _extractSpeakableReply(aiBuffer.toString());
        aiBuffer.clear();
        if (mounted) {
          setState(() => _awaitingReply = false);
        } else {
          _awaitingReply = false;
        }
        _cancelMicRestart();

        if (reply.isNotEmpty) {
          _chatHistory.add({
            'role': 'assistant',
            'content': reply,
          });
          if (mounted) setState(() {});
          _speak(reply);
        } else {
          _scheduleMicRestart();
        }
        return;
      }

      if (msg.startsWith(_metaPrefix)) {
        try {
          final meta = jsonDecode(msg.substring(_metaPrefix.length));
          if (meta is Map && meta['role'] != null) {
            _responderRole = meta['role'].toString();
          }
        } catch (_) {}
        return;
      }

      aiBuffer.write(msg);
    });

    Future.delayed(const Duration(milliseconds: 300), () {
      if (!_simulationActive) return;
      _awaitingReply = true;
      _channel?.sink.add(jsonEncode(_wsPayload(userText: '')));
    });
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
    try {
      _channel?.sink.close();
    } catch (_) {}
    _tts.stop();
    _isSpeaking = false;
    _micActive = false;
    setState(() {});
  }

  Future<void> _speak(String text) async {
    _cancelMicRestart();
    _isSpeaking = true;
    if (mounted) setState(() => _micActive = false);
    try {
      await _speech.stop();
    } catch (_) {}
    await _tts.stop();

    final role = (_responderRole ?? '').toUpperCase();
    final preferMale = role != 'TERZO';
    await _configureTtsVoice(preferMale: preferMale);

    _tts.setCompletionHandler(() {
      _isSpeaking = false;
      if (_simulationActive) {
        _scheduleMicRestart();
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
                              : _micActive
                                  ? 'Microfono attivo — parla liberamente'
                                  : _needsMicTap
                                      ? 'Microfono in pausa — tocca per riattivare'
                                      : 'Avvio microfono...',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 10),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: _micActive
                            ? const Color(0xFFC62828)
                            : Colors.lightBlueAccent.shade700,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: (_awaitingReply || _isSpeaking)
                          ? null
                          : _requestMicrophone,
                      icon: Icon(_micActive ? Icons.mic : Icons.mic_none_outlined),
                      label: Text(
                        _micActive
                            ? 'In ascolto'
                            : _needsMicTap
                                ? 'Riattiva microfono'
                                : 'Microfono',
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
              onOpenSimulation: () => _startSimulation(
                {
                  'title': title,
                  'prompt': data['prompt'] ?? '',
                  'practiceData': practiceData,
                  'scenarioWeights':
                      data['scenarioWeights'] as Map<String, dynamic>?,
                },
                simulationId: doc.id,
                category: type,
              ),
              onStopSimulation: () => _stopSimulation(),
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