import 'dart:async';

import 'package:credit_calc_core/credit_calc_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import 'roleplay_conversation_service.dart';
import 'roleplay_event.dart';
import 'roleplay_session.dart';
import 'roleplay_voice_status.dart';

/// Motore roleplay GPT: STT locale, TTS locale, turni via Firebase `roleplayStep`.
class RoleplayGptSession implements RoleplaySession {
  RoleplayGptSession({
    required this.onStateChanged,
    required this.onError,
    required this.isContextActive,
    SpeechToText? speech,
    FlutterTts? tts,
  })  : _speech = speech ?? SpeechToText(),
        _tts = tts ?? FlutterTts();

  final VoidCallback onStateChanged;
  final void Function(String message) onError;
  final bool Function() isContextActive;

  final _events = StreamController<RoleplayEvent>.broadcast();

  @override
  Stream<RoleplayEvent> get events => _events.stream;

  final SpeechToText _speech;
  final FlutterTts _tts;

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
  final List<Map<String, String>> _chatHistory = [];

  @override
  bool get isActive => _simulationActive;

  bool get awaitingReply => _awaitingReply;
  bool get isSpeaking => _isSpeaking;
  bool get micListening => _micListening;
  String? get responderRole => _responderRole;

  @override
  List<Map<String, String>> get history =>
      List<Map<String, String>>.unmodifiable(_chatHistory);

  List<Map<String, String>> get chatHistory => history;

  @override
  RoleplayVoiceStatus get voiceStatus {
    if (!_simulationActive) return RoleplayVoiceStatus.idle;
    if (_awaitingReply) return RoleplayVoiceStatus.thinking;
    if (_isSpeaking) return RoleplayVoiceStatus.speaking;
    return RoleplayVoiceStatus.listening;
  }

  bool get _shouldKeepListening =>
      _simulationActive && !_isSpeaking && !_awaitingReply;

  void _notifyState() {
    _events.add(StatusEvent(voiceStatus));
    if (isContextActive()) {
      onStateChanged();
    }
  }

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
      if (!isContextActive()) return;
      try {
        action();
      } catch (e, st) {
        debugPrint('Speech handler error: $e\n$st');
      }
    });
  }

  @override
  Future<void> init() async {
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
    if (!isContextActive()) return;

    if (status == 'listening') {
      if (!_micListening) {
        _micListening = true;
        _notifyState();
      }
      return;
    }

    if (status == 'done' || status == 'notListening') {
      if (_micListening) {
        _micListening = false;
        _notifyState();
      }
      if (_shouldKeepListening) {
        _scheduleContinuousListening();
      }
    }
  }

  void _handleSpeechError(SpeechRecognitionError error) {
    if (!isContextActive()) return;

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

    _awaitingReply = true;
    _notifyState();

    try {
      unawaited(_speech.stop().catchError((_) {}));
      _micListening = false;
      _notifyState();

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

      if (!isContextActive() || !_simulationActive) return;

      final reply = (result['reply'] ?? '').toString().trim();
      if (result['role'] != null) {
        _responderRole = result['role'].toString();
      }

      if (reply.isNotEmpty) {
        _chatHistory.add({'role': 'assistant', 'content': reply});
        _notifyState();
        await _speak(reply);
      } else if (_simulationActive && isContextActive()) {
        _scheduleContinuousListening();
      }
    } catch (e, st) {
      debugPrint('Roleplay step error: $e\n$st');
      if (isContextActive() && _simulationActive) {
        const message = 'Errore nella simulazione. Riprova a parlare.';
        onError('$message\n$e');
        _events.add(ErrorEvent('$message\n$e'));
        _scheduleContinuousListening();
      }
    } finally {
      if (isContextActive()) {
        _awaitingReply = false;
        _notifyState();
      }
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

    if (!isContextActive() || !_simulationActive) return;
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
      if (!isContextActive() || !_shouldKeepListening) return;
      if (!_speech.isListening) {
        _scheduleContinuousListening(delay: const Duration(milliseconds: 300));
      }
    });
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

      if (!_shouldKeepListening || !isContextActive()) return;

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

  Future<void> _speak(String text) async {
    _cancelMicRestart();
    _isSpeaking = true;
    _micListening = false;
    _notifyState();
    try {
      unawaited(_speech.stop().catchError((_) {}));
      await _tts.stop();

      final role = (_responderRole ?? '').toUpperCase();
      final preferMale = role != 'TERZO';
      await _configureTtsVoice(preferMale: preferMale);

      await _tts.awaitSpeakCompletion(true);
      _tts.setCompletionHandler(() {
        _isSpeaking = false;
        if (_simulationActive && isContextActive()) {
          _scheduleContinuousListening();
        }
      });
      await _tts.speak(text);
    } catch (e, st) {
      debugPrint('TTS error: $e\n$st');
      _isSpeaking = false;
      if (_simulationActive && isContextActive()) {
        _scheduleContinuousListening();
      }
    }
  }

  @override
  Future<void> start({
    required Map<String, dynamic> simulationData,
    required String sessionId,
  }) async {
    _currentSimulation = simulationData;
    _chatHistory.clear();
    _lastUserText = '';
    _sessionId = sessionId;
    _awaitingReply = false;
    _micListening = false;
    _responderRole = null;

    _simulationActive = true;
    _notifyState();

    _stopSpeech();
    if (!_speechReady) {
      await init();
    }

    await _requestRoleplayReply(userText: '');
  }

  @override
  Future<void> stop() async {
    _simulationActive = false;
    _currentSimulation = null;

    _stopSpeech();
    _tts.stop();
    _isSpeaking = false;
    _micListening = false;
    _notifyState();
  }

  @override
  void dispose() {
    _stopSpeech();
    _tts.stop();
    unawaited(_events.close());
  }
}
