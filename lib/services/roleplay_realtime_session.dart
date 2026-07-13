import 'dart:async';
import 'dart:convert';

import 'package:credit_calc_core/credit_calc_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../config/roleplay_ai_provider.dart';
import '../config/roleplay_backend_config.dart';
import 'roleplay_event.dart';
import 'roleplay_realtime_audio.dart';
import 'roleplay_realtime_audio_platform.dart';
import 'roleplay_realtime_session_config.dart';
import 'roleplay_session.dart';
import 'roleplay_voice_status.dart';

/// Motore roleplay OpenAI Realtime: audio bidirezionale via proxy backend.
class RoleplayRealtimeSession implements RoleplaySession {
  RoleplayRealtimeSession({
    required this.onStateChanged,
    required this.onError,
    required this.isContextActive,
    RoleplayRealtimeAudio? audio,
  }) : _audio = audio ?? createRoleplayRealtimeAudio();

  final VoidCallback onStateChanged;
  final void Function(String message) onError;
  final bool Function() isContextActive;

  final RoleplayRealtimeAudio _audio;
  final _events = StreamController<RoleplayEvent>.broadcast();

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _socketSubscription;
  Timer? _connectTimeoutTimer;

  bool _simulationActive = false;
  bool _connected = false;
  bool _bootstrapped = false;
  bool _speaking = false;
  RoleplayVoiceStatus _status = RoleplayVoiceStatus.idle;

  String _sessionId = 'default';
  Map<String, dynamic>? _currentSimulation;
  String? _responderRole;
  final List<Map<String, String>> _history = [];
  String _assistantBuffer = '';

  // Metriche collaudo (solo debug).
  DateTime? _qaStartedAt;
  DateTime? _qaUserSpeechStoppedAt;
  bool _qaLoggedFirstAudio = false;
  int _qaTurnCount = 0;

  void _qaLog(String label, {DateTime? since}) {
    if (!kDebugMode) return;
    final elapsed = since == null
        ? ''
        : ' +${DateTime.now().difference(since).inMilliseconds}ms';
    debugPrint('RoleplayRealtime QA: $label$elapsed');
  }

  @override
  Stream<RoleplayEvent> get events => _events.stream;

  @override
  bool get isActive => _simulationActive;

  @override
  List<Map<String, String>> get history =>
      List<Map<String, String>>.unmodifiable(_history);

  @override
  RoleplayVoiceStatus get voiceStatus => _status;

  @override
  Future<void> init() async {}

  void _setStatus(RoleplayVoiceStatus status) {
    if (_status == status) return;
    _status = status;
    _events.add(StatusEvent(status));
    if (isContextActive()) onStateChanged();
  }

  void _emitError(String message) {
    _events.add(ErrorEvent(message));
    _setStatus(RoleplayVoiceStatus.error);
    if (isContextActive()) onError(message);
  }

  void _emitTranscript(String speaker, String text, {bool isFinal = true}) {
    _events.add(
      TranscriptEvent(speaker: speaker, text: text, isFinal: isFinal),
    );
    if (isContextActive()) onStateChanged();
  }

  Future<void> _connect() async {
    if (_connected) return;
    _setStatus(RoleplayVoiceStatus.connecting);

    final completer = Completer<void>();
    try {
      _channel = WebSocketChannel.connect(
        Uri.parse(RoleplayBackendConfig.realtimeWebSocketUrl),
      );
    } catch (_) {
      _emitError('Impossibile aprire la connessione Realtime.');
      return;
    }

    _connectTimeoutTimer = Timer(const Duration(seconds: 12), () {
      if (!completer.isCompleted) {
        completer.completeError('Timeout connessione Realtime.');
      }
    });

    _socketSubscription = _channel!.stream.listen(
      _onSocketMessage,
      onError: (_) {
        if (!completer.isCompleted) {
          completer.completeError('Errore WebSocket Realtime.');
        }
        if (_simulationActive) {
          _emitError(
            'Servizio Realtime non disponibile. '
            'Verifica la connessione e riprova.',
          );
        }
      },
      onDone: () {
        _connected = false;
        if (_simulationActive) {
          _setStatus(RoleplayVoiceStatus.idle);
        }
      },
    );

    try {
      await _channel!.ready;
      _connected = true;
      _connectTimeoutTimer?.cancel();
      if (!completer.isCompleted) completer.complete();
      await completer.future;
    } catch (e) {
      _connectTimeoutTimer?.cancel();
      _emitError(
        e.toString().contains('Timeout')
            ? 'Servizio Realtime non disponibile (timeout). Riprova.'
            : e.toString(),
      );
    }
  }

  Future<void> _bootstrap() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _emitError('Accesso richiesto per la simulazione Realtime.');
      return;
    }

    final idToken = await user.getIdToken();
    if (idToken == null || idToken.isEmpty) {
      _emitError('Token di autenticazione non disponibile.');
      return;
    }

    final sessionUpdate = RoleplayRealtimeSessionConfig.buildSessionUpdate(
      simulationData: _currentSimulation ?? const {},
      sessionId: _sessionId,
      responderRole: _responderRole,
    );

    _sendJson({
      'type': 'session.bootstrap',
      'sessionId': _sessionId,
      'idToken': idToken,
      'provider': RoleplayAiProvider.realtime,
      'sessionUpdate': sessionUpdate,
    });
  }

  @override
  Future<void> start({
    required Map<String, dynamic> simulationData,
    required String sessionId,
  }) async {
    await stop();

    _currentSimulation = simulationData;
    _sessionId = sessionId;
    _responderRole = null;
    _history.clear();
    _assistantBuffer = '';
    _simulationActive = true;
    _bootstrapped = false;
    _qaStartedAt = kDebugMode ? DateTime.now() : null;
    _qaUserSpeechStoppedAt = null;
    _qaLoggedFirstAudio = false;
    _qaTurnCount = 0;
    _qaLog('start simulazione', since: _qaStartedAt);

    if (!_connected) {
      await _connect();
    }
    if (!_connected || _channel == null) return;

    await _bootstrap();

    try {
      await _audio.startMicrophone(_sendMicChunk);
      _setStatus(RoleplayVoiceStatus.listening);
    } catch (e) {
      _emitError(
        e.toString().contains('Permesso')
            ? 'Permesso microfono negato. Consenti l\'accesso al microfono.'
            : 'Microfono non disponibile per Realtime.',
      );
    }
  }

  void _sendMicChunk(List<int> pcmChunk) {
    if (!_simulationActive || !_bootstrapped || pcmChunk.isEmpty) return;
    _sendJson({
      'type': 'input_audio_buffer.append',
      'audio': base64Encode(pcmChunk),
    });
  }

  @override
  Future<void> stop() async {
    _simulationActive = false;
    _speaking = false;
    _bootstrapped = false;
    _connectTimeoutTimer?.cancel();

    await _audio.stopMicrophone();
    await _audio.stopPlayback();

    if (_connected) {
      _sendJson({'type': 'session.stop', 'sessionId': _sessionId});
    }

    _currentSimulation = null;
    _setStatus(RoleplayVoiceStatus.idle);
  }

  @override
  void dispose() {
    unawaited(stop());
    _socketSubscription?.cancel();
    _socketSubscription = null;
    try {
      _channel?.sink.close();
    } catch (_) {}
    _channel = null;
    _connected = false;
    unawaited(_audio.dispose());
    unawaited(_events.close());
  }

  void _sendJson(Map<String, dynamic> payload) {
    if (_channel == null) return;
    try {
      _channel!.sink.add(jsonEncode(payload));
    } catch (_) {}
  }

  void _onSocketMessage(dynamic raw) {
    if (!_simulationActive) return;
    final text = raw?.toString() ?? '';
    if (text.isEmpty) return;

    Map<String, dynamic>? event;
    try {
      final parsed = jsonDecode(text);
      if (parsed is Map) {
        event = Map<String, dynamic>.from(parsed);
      }
    } catch (_) {
      return;
    }
    if (event == null) return;

    final type = event['type']?.toString() ?? '';

    switch (type) {
      case 'proxy.ping':
        _sendJson({'type': 'proxy.pong'});
        return;
      case 'proxy.ready':
        _bootstrapped = true;
        _setStatus(RoleplayVoiceStatus.listening);
        _qaLog('proxy.ready (sessione aperta)', since: _qaStartedAt);
        return;
      case 'proxy.reconnecting':
        _setStatus(RoleplayVoiceStatus.connecting);
        return;
      case 'proxy.disconnected':
        _bootstrapped = false;
        _emitError('Connessione Realtime interrotta dal server.');
        return;
      case 'proxy.error':
        _emitError(event['message']?.toString() ?? 'Errore Realtime.');
        return;
      case 'input_audio_buffer.speech_started':
        if (_speaking) _interruptAssistant();
        _setStatus(RoleplayVoiceStatus.listening);
        return;
      case 'input_audio_buffer.speech_stopped':
        _setStatus(RoleplayVoiceStatus.thinking);
        _qaUserSpeechStoppedAt = kDebugMode ? DateTime.now() : null;
        _qaTurnCount++;
        _qaLog('turn $_qaTurnCount speech_stopped');
        return;
      case 'response.created':
        _setStatus(RoleplayVoiceStatus.thinking);
        return;
      case 'response.audio.delta':
        final delta = event['delta']?.toString();
        if (delta != null && delta.isNotEmpty) {
          if (kDebugMode && !_qaLoggedFirstAudio) {
            _qaLoggedFirstAudio = true;
            _qaLog(
              'prima risposta audio',
              since: _qaStartedAt,
            );
          }
          if (kDebugMode && _qaUserSpeechStoppedAt != null) {
            _qaLog(
              'audio dopo turno $_qaTurnCount',
              since: _qaUserSpeechStoppedAt,
            );
            _qaUserSpeechStoppedAt = null;
          }
          _speaking = true;
          _setStatus(RoleplayVoiceStatus.speaking);
          unawaited(_audio.playPcm16Base64Delta(delta));
        }
        return;
      case 'response.audio_transcript.delta':
        final delta = event['delta']?.toString() ?? '';
        if (delta.isNotEmpty) {
          _assistantBuffer += delta;
          _emitTranscript('debitore', _assistantBuffer, isFinal: false);
        }
        return;
      case 'response.audio_transcript.done':
        final transcript = event['transcript']?.toString() ?? _assistantBuffer;
        if (transcript.trim().isNotEmpty) {
          _history.add({'role': 'assistant', 'content': transcript.trim()});
          _emitTranscript('debitore', transcript.trim());
        }
        _assistantBuffer = '';
        return;
      case 'conversation.item.input_audio_transcription.completed':
        final transcript = event['transcript']?.toString() ?? '';
        if (transcript.trim().isNotEmpty) {
          _history.add({'role': 'user', 'content': transcript.trim()});
          _emitTranscript('consulente', transcript.trim());
        }
        return;
      case 'response.done':
        _speaking = false;
        _setStatus(RoleplayVoiceStatus.listening);
        return;
      case 'error':
        _emitError(
          event['error'] is Map
              ? (event['error'] as Map)['message']?.toString() ??
                  'Errore Realtime.'
              : 'Errore Realtime.',
        );
        return;
      default:
        return;
    }
  }

  void _interruptAssistant() {
    _speaking = false;
    unawaited(_audio.stopPlayback());
    _sendJson({'type': 'response.cancel'});
    if (_history.isNotEmpty && _history.last['role'] == 'assistant') {
      _history.removeLast();
    }
    _assistantBuffer = '';
    _setStatus(RoleplayVoiceStatus.listening);
  }
}
