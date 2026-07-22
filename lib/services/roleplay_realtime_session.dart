import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'callable_function_client.dart';
import 'roleplay_event.dart';
import 'roleplay_realtime_audio.dart';
import 'roleplay_realtime_audio_probe.dart';
import 'roleplay_realtime_audio_probe_io.dart'
    if (dart.library.html) 'roleplay_realtime_audio_probe_stub.dart';
import 'roleplay_realtime_audio_platform.dart';
import 'roleplay_realtime_audio_rates.dart';
import 'roleplay_realtime_session_config.dart';
import 'roleplay_realtime_ws.dart';
import 'roleplay_session.dart';
import 'roleplay_voice_status.dart';

/// Motore roleplay OpenAI Realtime via Firebase (token ephemeral) + WS diretto.
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
  /// True solo dopo `session.updated` (VAD/config applicati).
  bool _sessionUpdatedReceived = false;
  bool _speaking = false;
  bool _micMutedForOutput = false;
  bool _greetingRequested = false;
  bool _openingGreetingDone = false;
  /// Solo dopo sessione pronta + settle + greeting AI + warm-up mic.
  bool _micCaptureEnabled = false;
  /// Dopo warm-up: scarta silenzio/rumore finché non arriva PCM utilizzabile.
  bool _skipLeadingSilence = false;
  DateTime? _micWarmupUntil;
  Timer? _micUnmuteTimer;
  Completer<void>? _sessionReadyCompleter;
  Completer<void>? _openingGreetingCompleter;
  RoleplayVoiceStatus _status = RoleplayVoiceStatus.idle;

  String _sessionId = 'default';
  Map<String, dynamic>? _currentSimulation;
  String? _responderRole;
  final List<Map<String, String>> _history = [];
  String _assistantBuffer = '';

  DateTime? _qaStartedAt;
  DateTime? _qaUserSpeechStoppedAt;
  DateTime? _greetingCreateAt;
  DateTime? _greetingFirstAudioAt;
  DateTime? _micOpenedAt;
  DateTime? _firstPcmSentAt;
  DateTime? _firstFinalTranscriptAt;
  bool _qaLoggedFirstAudio = false;
  bool _loggedFirstMicFrameSent = false;
  bool _loggedFirstAudioReceived = false;
  bool _loggedFirstFinalTranscript = false;
  bool _loggedVadReady = false;
  int _qaTurnCount = 0;
  RoleplayPcmPipelineProbe? _sentAudioProbe;
  bool _sentWavFlushed = false;

  static const _postConnectSettle = Duration(milliseconds: 750);
  /// Warm-up post-apertura AudioRecorder (scarta frame incompleti).
  static const _micWarmup = Duration(milliseconds: 600);
  static const _postGreetingSync = Duration(milliseconds: 250);
  /// Peak PCM16 sotto questa soglia = silenzio / rumore di avvio.
  static const _silencePeakThreshold = 180;

  void _pipelineLog(String label, {DateTime? since}) {
    if (!kDebugMode) return;
    final ts = DateTime.now().toIso8601String();
    final elapsed = since == null
        ? ''
        : ' +${DateTime.now().difference(since).inMilliseconds}ms';
    debugPrint('RoleplayRealtime pipeline [$ts]$elapsed: $label');
  }

  void _qaLog(String label, {DateTime? since}) {
    _pipelineLog(label, since: since);
  }

  /// Hallucination tipiche Whisper su silenzio / rumore di avvio.
  static bool _isSpuriousTranscript(String text) {
    final t = text.trim().toLowerCase();
    if (t.isEmpty) return true;
    if (t.length < 2) return true;
    return t.contains('amara.org') ||
        t.contains('sottotitoli creati') ||
        t.contains('sottotitoli generati') ||
        t.contains('sous-titres') ||
        t.contains('subtitles by') ||
        t.contains('a cura di qtss') ||
        t.contains('revisione a cura di qtss');
  }

  /// PCM16 LE mono: true se quasi silenzioso o troppo corto (frame corrotto).
  static bool _isUnusablePcm(List<int> pcm) {
    if (pcm.length < 8) return true;
    // Lunghezza dispari = stream corrotto / incompleto.
    if (pcm.length.isOdd) return true;
    var peak = 0;
    for (var i = 0; i + 1 < pcm.length; i += 4) {
      final lo = pcm[i] & 0xff;
      final hi = pcm[i + 1] & 0xff;
      var sample = lo | (hi << 8);
      if (sample > 32767) sample -= 65536;
      final abs = sample.abs();
      if (abs > peak) peak = abs;
      if (peak >= _silencePeakThreshold) return false;
    }
    return peak < _silencePeakThreshold;
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
    // Cronologia / UI: solo finali.
    if (!isFinal) return;
    _events.add(
      TranscriptEvent(speaker: speaker, text: text, isFinal: true),
    );
    if (isContextActive()) onStateChanged();
  }

  void _clearInputAudioBuffer() {
    _sendJson({'type': 'input_audio_buffer.clear'});
  }

  Future<Map<String, dynamic>> _mintFirebaseRealtimeToken() async {
    final data = await CallableFunctionClient.call(
      'roleplayRealtimeToken',
      const <String, dynamic>{},
    );
    if (data is! Map) {
      throw StateError('Token Realtime non valido.');
    }
    final map = Map<String, dynamic>.from(data);
    final token = (map['token'] ?? '').toString().trim();
    final wsUrl = (map['wsUrl'] ?? '').toString().trim();
    if (token.isEmpty || wsUrl.isEmpty) {
      throw StateError('Token o URL Realtime assenti.');
    }
    return map;
  }

  Future<void> _connect() async {
    if (_connected) return;
    _setStatus(RoleplayVoiceStatus.connecting);

    final completer = Completer<void>();
    try {
      final minted = await _mintFirebaseRealtimeToken();
      final token = minted['token'].toString();
      final wsUrl = minted['wsUrl'].toString();
      _channel = connectOpenAiRealtimeWs(
        uri: Uri.parse(wsUrl),
        ephemeralToken: token,
      );
    } catch (e) {
      _emitError(
        e.toString().contains('UnsupportedError')
            ? e.toString()
            : 'Servizio Realtime non disponibile. Verifica la connessione e riprova.',
      );
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
      _pipelineLog('connessione WebSocket', since: _qaStartedAt);
    } catch (e) {
      _connectTimeoutTimer?.cancel();
      _emitError(
        e.toString().contains('Timeout')
            ? 'Servizio Realtime non disponibile (timeout). Riprova.'
            : e.toString(),
      );
    }
  }

  Future<void> _bootstrapAndWaitReady() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _emitError('Accesso richiesto per la simulazione Realtime.');
      return;
    }

    _sessionUpdatedReceived = false;
    _sessionReadyCompleter = Completer<void>();
    final ready = _sessionReadyCompleter!;

    final sessionUpdate = RoleplayRealtimeSessionConfig.buildSessionUpdate(
      simulationData: _currentSimulation ?? const {},
      sessionId: _sessionId,
      responderRole: _responderRole,
    );

    _sendJson(sessionUpdate);
    _pipelineLog(
      'session.update inviato (attendo session.updated)',
      since: _qaStartedAt,
    );

    try {
      await ready.future.timeout(const Duration(seconds: 10));
    } on TimeoutException {
      _emitError(
        'Servizio Realtime non disponibile (timeout sessione). Riprova.',
      );
      return;
    } catch (_) {
      // stop() o chiusura anticipata
      return;
    }
  }

  Future<void> _waitOpeningGreetingDone() async {
    if (_openingGreetingDone) return;
    final c = _openingGreetingCompleter;
    if (c == null) return;
    try {
      await c.future.timeout(const Duration(seconds: 15));
    } on TimeoutException {
      _pipelineLog(
        'timeout greeting iniziale — sblocco mic comunque',
        since: _qaStartedAt,
      );
      _openingGreetingDone = true;
    }

    // Attende fine coda altoparlante (anti-eco sul "Pronto?").
    final deadline = DateTime.now().add(const Duration(seconds: 8));
    while (_simulationActive &&
        _audio.isOutputActive &&
        DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 80));
    }
    if (_simulationActive) {
      await Future<void>.delayed(_postGreetingSync);
    }

    final createAt = _greetingCreateAt;
    final firstAudio = _greetingFirstAudioAt;
    if (createAt != null) {
      final totalMs = DateTime.now().difference(createAt).inMilliseconds;
      final audioMs = firstAudio == null
          ? 'n/d'
          : '${DateTime.now().difference(firstAudio).inMilliseconds}ms audio';
      _pipelineLog(
        'durata effettiva greeting: ${totalMs}ms (da response.create; $audioMs)',
        since: _qaStartedAt,
      );
    }
  }

  Future<void> _enableMicrophoneAfterReady() async {
    if (!_simulationActive || !_bootstrapped || !_openingGreetingDone) return;

    // Hard gate: nessun PCM verso OpenAI finché warm-up + silenzio iniziale ok.
    _micMutedForOutput = true;
    _micCaptureEnabled = false;
    _skipLeadingSilence = false;
    _loggedFirstMicFrameSent = false;
    _firstPcmSentAt = null;
    _sentWavFlushed = false;
    _sentAudioProbe = RoleplayPcmPipelineProbe(
      tag: 'sent-openai',
      declaredSampleRate: kRoleplayOpenAiPcmRateHz,
    );

    try {
      // Microfono spento per tutto il greeting: parte solo ora.
      await _audio.startMicrophone(_sendMicChunk);
      _micOpenedAt = DateTime.now();
      _pipelineLog(
        'istante apertura microfono: ${_micOpenedAt!.toIso8601String()}',
        since: _qaStartedAt,
      );
      _micWarmupUntil = DateTime.now().add(_micWarmup);

      // Warm-up: callback AudioRecorder attivi ma scartati (_micCaptureEnabled=false).
      await Future<void>.delayed(_micWarmup);
      if (!_simulationActive) return;

      _clearInputAudioBuffer();
      _micWarmupUntil = null;
      _skipLeadingSilence = true;
      _micMutedForOutput = false;
      _micCaptureEnabled = true;
      if (!_loggedVadReady) {
        _loggedVadReady = true;
        _pipelineLog(
          'attivazione VAD / mic pronto '
          '(warm-up ${_micWarmup.inMilliseconds}ms + skip silenzio iniziale)',
          since: _qaStartedAt,
        );
      }
      _setStatus(RoleplayVoiceStatus.listening);
    } catch (e) {
      _emitError(
        e.toString().contains('Permesso')
            ? 'Permesso microfono negato. Consenti l\'accesso al microfono.'
            : 'Microfono non disponibile per Realtime.',
      );
    }
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
    _sessionUpdatedReceived = false;
    _greetingRequested = false;
    _openingGreetingDone = false;
    _micCaptureEnabled = false;
    _skipLeadingSilence = false;
    _micWarmupUntil = null;
    _qaStartedAt = kDebugMode ? DateTime.now() : null;
    _qaUserSpeechStoppedAt = null;
    _greetingCreateAt = null;
    _greetingFirstAudioAt = null;
    _micOpenedAt = null;
    _firstPcmSentAt = null;
    _firstFinalTranscriptAt = null;
    _qaLoggedFirstAudio = false;
    _loggedFirstMicFrameSent = false;
    _loggedFirstAudioReceived = false;
    _loggedFirstFinalTranscript = false;
    _loggedVadReady = false;
    _qaTurnCount = 0;
    _sentAudioProbe = null;
    _sentWavFlushed = false;
    _pipelineLog('start simulazione', since: _qaStartedAt);

    if (!_connected) {
      await _connect();
    }
    if (!_connected || _channel == null || !_simulationActive) return;

    await _bootstrapAndWaitReady();
    if (!_sessionUpdatedReceived || !_bootstrapped || !_simulationActive) {
      return;
    }

    // Settle post-connessione prima di greeting / mic (500–1000 ms).
    _pipelineLog(
      'settle post-connessione ${_postConnectSettle.inMilliseconds}ms',
      since: _qaStartedAt,
    );
    await Future<void>.delayed(_postConnectSettle);
    if (!_simulationActive || !_sessionUpdatedReceived) return;

    // Nessun evento AI prima di session.updated (già atteso sopra).
    _requestOpeningGreeting();
    await _waitOpeningGreetingDone();
    if (!_simulationActive) return;

    await _enableMicrophoneAfterReady();
  }

  void _requestOpeningGreeting() {
    if (!_simulationActive || _greetingRequested) return;
    // Garanzia: nessun response.create prima di session.updated.
    if (!_sessionUpdatedReceived || !_bootstrapped) {
      _pipelineLog(
        'BLOCCATO response.create: session.updated non ricevuto',
        since: _qaStartedAt,
      );
      return;
    }
    _greetingRequested = true;
    _openingGreetingCompleter = Completer<void>();
    _greetingCreateAt = DateTime.now();
    // Mic ancora non aperto: mute + clear preventivi su buffer server.
    _muteMicForAssistantOutput();
    _sendJson({
      'type': 'response.create',
      'response': {
        'instructions':
            'Rispondi al telefono con un solo breve "Pronto?" naturale, '
            'poi taci. Non dire altro. Non interpretare il consulente.',
      },
    });
    _pipelineLog(
      'response.create Pronto? (post session.updated)',
      since: _qaStartedAt,
    );
  }

  void _completeOpeningGreetingIfNeeded() {
    if (_openingGreetingDone) return;
    if (!_greetingRequested) return;
    _openingGreetingDone = true;
    final c = _openingGreetingCompleter;
    if (c != null && !c.isCompleted) {
      c.complete();
    }
    _pipelineLog('greeting iniziale completato (response.done)', since: _qaStartedAt);
  }

  void _sendMicChunk(List<int> pcmChunk) {
    // Race-safe: durante greeting / pre-arm nessun frame lascia il device.
    if (!_simulationActive || !_bootstrapped || pcmChunk.isEmpty) return;
    if (!_openingGreetingDone) return;
    if (!_micCaptureEnabled) return;
    final warmup = _micWarmupUntil;
    if (warmup != null && DateTime.now().isBefore(warmup)) return;
    // Evita eco: mentre l'AI parla (o coda altoparlante) non inviare mic.
    if (_speaking || _micMutedForOutput || _audio.isOutputActive) return;

    if (_skipLeadingSilence) {
      if (_isUnusablePcm(pcmChunk)) {
        return;
      }
      // Primo frame con energia utile: buffer pulito e poi trasmetti.
      _skipLeadingSilence = false;
      _clearInputAudioBuffer();
      _pipelineLog(
        'primo frame PCM utilizzabile (fine skip silenzio)',
        since: _qaStartedAt,
      );
    } else if (_isUnusablePcm(pcmChunk) && !_loggedFirstMicFrameSent) {
      // Non mandare silenzio/corrotto come all-time-first frame.
      return;
    }

    if (!_loggedFirstMicFrameSent) {
      _loggedFirstMicFrameSent = true;
      _firstPcmSentAt = DateTime.now();
      final sinceMic = _micOpenedAt == null
          ? 'n/d'
          : '${_firstPcmSentAt!.difference(_micOpenedAt!).inMilliseconds}ms dopo apertura mic';
      final endianCheck = pcmChunk.length >= 4
          ? 's16le samples[0..1]=['
              '${_readS16Le(pcmChunk, 0)}, ${_readS16Le(pcmChunk, 2)}]'
          : 'too-short';
      _pipelineLog(
        'istante primo chunk PCM inviato: '
        '${_firstPcmSentAt!.toIso8601String()} ($sinceMic) '
        'bytes=${pcmChunk.length} $endianCheck '
        'pcmRate=${kRoleplayOpenAiPcmRateHz}Hz == session.audio.input.format.rate '
        'formato=PCM16 LE mono base64→input_audio_buffer.append',
        since: _qaStartedAt,
      );
      // ignore: avoid_print
      print(
        'RoleplayAudio APPEND confirm: '
        'pcmBytes=${pcmChunk.length} '
        'effectivePcmHz=$kRoleplayOpenAiPcmRateHz '
        'openaiSessionHz=$kRoleplayOpenAiPcmRateHz '
        'match=true',
      );
      assert(
        kRoleplayOpenAiPcmRateHz == 24000,
        'input_audio_buffer.append deve usare PCM @ rate sessione OpenAI',
      );
    }
    _sentAudioProbe?.ingest(pcmChunk);
    if (_sentAudioProbe != null &&
        _sentAudioProbe!.hasFullCapture &&
        !_sentWavFlushed) {
      _sentWavFlushed = true;
      unawaited(_flushSentAudioWav());
    }
    _sendJson({
      'type': 'input_audio_buffer.append',
      'audio': base64Encode(pcmChunk),
    });
  }

  static int _readS16Le(List<int> pcm, int offset) {
    var sample = (pcm[offset] & 0xff) | ((pcm[offset + 1] & 0xff) << 8);
    if (sample > 32767) sample -= 65536;
    return sample;
  }

  Future<void> _flushSentAudioWav() async {
    final probe = _sentAudioProbe;
    if (probe == null) return;
    final path = await writeRoleplayProbeWav(probe: probe);
    probe.logSummary();
    _pipelineLog(
      'WAV primi 3s inviati a OpenAI: ${path ?? '(non scritto)'} — '
      'se il file è pulito ma la trascrizione no → post-invio; '
      'se il file è distorto → pipeline locale',
      since: _qaStartedAt,
    );
  }

  void _muteMicForAssistantOutput() {
    _micMutedForOutput = true;
    _clearInputAudioBuffer();
    _micUnmuteTimer?.cancel();
  }

  void _scheduleMicUnmute() {
    // Prima del greeting / warm-up non sbloccare il mic.
    if (!_micCaptureEnabled || !_openingGreetingDone) {
      _clearInputAudioBuffer();
      return;
    }
    _micUnmuteTimer?.cancel();
    _micUnmuteTimer = Timer.periodic(const Duration(milliseconds: 80), (t) {
      if (!_simulationActive) {
        t.cancel();
        return;
      }
      if (_speaking || _audio.isOutputActive) return;
      t.cancel();
      _clearInputAudioBuffer();
      _micMutedForOutput = false;
      _setStatus(RoleplayVoiceStatus.listening);
    });
  }

  @override
  Future<void> stop() async {
    _simulationActive = false;
    _speaking = false;
    _micMutedForOutput = false;
    _micCaptureEnabled = false;
    _skipLeadingSilence = false;
    _micWarmupUntil = null;
    _greetingRequested = false;
    _openingGreetingDone = false;
    _sessionUpdatedReceived = false;
    _micUnmuteTimer?.cancel();
    _micUnmuteTimer = null;
    _bootstrapped = false;
    _connectTimeoutTimer?.cancel();

    final sessionReady = _sessionReadyCompleter;
    _sessionReadyCompleter = null;
    if (sessionReady != null && !sessionReady.isCompleted) {
      sessionReady.completeError(StateError('stopped'));
    }
    final greeting = _openingGreetingCompleter;
    _openingGreetingCompleter = null;
    if (greeting != null && !greeting.isCompleted) {
      greeting.complete();
    }

    await _audio.stopMicrophone();
    await _audio.stopPlayback();
    if (_sentAudioProbe != null && !_sentWavFlushed) {
      await _flushSentAudioWav();
    }
    _sentAudioProbe = null;

    _socketSubscription?.cancel();
    _socketSubscription = null;
    try {
      await _channel?.sink.close();
    } catch (_) {}
    _channel = null;
    _connected = false;

    _currentSimulation = null;
    _setStatus(RoleplayVoiceStatus.idle);
  }

  @override
  void dispose() {
    unawaited(stop());
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
      case 'session.created':
        // Connessione OK, ma VAD/config arrivano con session.updated.
        _pipelineLog('session.created', since: _qaStartedAt);
        return;
      case 'session.updated':
        _bootstrapped = true;
        _sessionUpdatedReceived = true;
        _setStatus(RoleplayVoiceStatus.listening);
        _pipelineLog('sessione pronta (session.updated)', since: _qaStartedAt);
        final ready = _sessionReadyCompleter;
        if (ready != null && !ready.isCompleted) {
          ready.complete();
        }
        // Greeting avviato da start() solo dopo questo evento + settle.
        return;
      case 'input_audio_buffer.speech_started':
        if (!_micCaptureEnabled ||
            !_openingGreetingDone ||
            _micMutedForOutput) {
          _clearInputAudioBuffer();
          return;
        }
        if (_speaking) _interruptAssistant();
        _setStatus(RoleplayVoiceStatus.listening);
        return;
      case 'input_audio_buffer.speech_stopped':
        if (!_micCaptureEnabled || !_openingGreetingDone) return;
        _setStatus(RoleplayVoiceStatus.thinking);
        _qaUserSpeechStoppedAt = kDebugMode ? DateTime.now() : null;
        _qaTurnCount++;
        _qaLog('turn $_qaTurnCount speech_stopped');
        return;
      case 'response.created':
        _setStatus(RoleplayVoiceStatus.thinking);
        return;
      case 'response.audio.delta':
      case 'response.output_audio.delta':
        final delta = event['delta']?.toString();
        if (delta != null && delta.isNotEmpty) {
          if (!_loggedFirstAudioReceived) {
            _loggedFirstAudioReceived = true;
            _greetingFirstAudioAt ??= DateTime.now();
            _pipelineLog('primo frame audio ricevuto', since: _qaStartedAt);
          }
          if (kDebugMode && !_qaLoggedFirstAudio) {
            _qaLoggedFirstAudio = true;
            _qaLog('prima risposta audio', since: _qaStartedAt);
          }
          if (kDebugMode && _qaUserSpeechStoppedAt != null) {
            _qaLog(
              'audio dopo turno $_qaTurnCount',
              since: _qaUserSpeechStoppedAt,
            );
            _qaUserSpeechStoppedAt = null;
          }
          _speaking = true;
          _muteMicForAssistantOutput();
          _setStatus(RoleplayVoiceStatus.speaking);
          unawaited(_audio.playPcm16Base64Delta(delta));
        }
        return;
      case 'response.audio_transcript.delta':
      case 'response.output_audio_transcript.delta':
        // Solo buffer interno; niente parziali in cronologia/UI.
        final delta = event['delta']?.toString() ?? '';
        if (delta.isNotEmpty) {
          _assistantBuffer += delta;
        }
        return;
      case 'response.audio_transcript.done':
      case 'response.output_audio_transcript.done':
        final transcript = event['transcript']?.toString() ?? _assistantBuffer;
        final trimmed = transcript.trim();
        if (trimmed.isNotEmpty && !_isSpuriousTranscript(trimmed)) {
          _history.add({'role': 'assistant', 'content': trimmed});
          _firstFinalTranscriptAt ??= DateTime.now();
          if (!_loggedFirstFinalTranscript) {
            _loggedFirstFinalTranscript = true;
            _pipelineLog(
              'istante prima trascrizione finale (AI): '
              '${_firstFinalTranscriptAt!.toIso8601String()} → "$trimmed"',
              since: _qaStartedAt,
            );
          }
          _emitTranscript('debitore', trimmed);
        }
        _assistantBuffer = '';
        return;
      case 'conversation.item.input_audio_transcription.completed':
        // Ignora qualsiasi trascrizione user prima che il mic sia armato.
        if (!_openingGreetingDone || !_micCaptureEnabled) {
          final early = event['transcript']?.toString() ?? '';
          if (early.trim().isNotEmpty) {
            _pipelineLog(
              'trascrizione user ignorata (pre-mic/greeting): ${early.trim()}',
              since: _qaStartedAt,
            );
          }
          return;
        }
        final transcript = event['transcript']?.toString() ?? '';
        final trimmed = transcript.trim();
        if (trimmed.isNotEmpty && !_isSpuriousTranscript(trimmed)) {
          _history.add({'role': 'user', 'content': trimmed});
          _firstFinalTranscriptAt ??= DateTime.now();
          if (!_loggedFirstFinalTranscript) {
            _loggedFirstFinalTranscript = true;
            _pipelineLog(
              'istante prima trascrizione finale (user): '
              '${_firstFinalTranscriptAt!.toIso8601String()} → "$trimmed"',
              since: _qaStartedAt,
            );
          } else {
            _pipelineLog(
              'trascrizione finale (user): "$trimmed"',
              since: _qaStartedAt,
            );
          }
          _emitTranscript('consulente', trimmed);
        } else if (trimmed.isNotEmpty) {
          _pipelineLog(
            'trascrizione spurio ignorata: $trimmed',
            since: _qaStartedAt,
          );
        }
        return;
      case 'response.done':
      case 'response.cancelled':
        _speaking = false;
        _clearInputAudioBuffer();
        unawaited(_audio.flushPlayback());
        _completeOpeningGreetingIfNeeded();
        _scheduleMicUnmute();
        return;
      case 'error':
        final message = event['error'] is Map
            ? (event['error'] as Map)['message']?.toString() ??
                'Errore Realtime.'
            : 'Errore Realtime.';
        final lower = message.toLowerCase();
        if (lower.contains('no active response') ||
            lower.contains('cancellation failed')) {
          // Coda audio / buffer: pulizia comunque.
          _clearInputAudioBuffer();
          return;
        }
        _emitError(message);
        return;
      default:
        return;
    }
  }

  void _interruptAssistant() {
    if (!_micCaptureEnabled || !_openingGreetingDone) {
      _clearInputAudioBuffer();
      return;
    }
    _speaking = false;
    _micUnmuteTimer?.cancel();
    // Resta muto finché la coda output non è ferma (anti-eco).
    _micMutedForOutput = true;
    unawaited(_audio.stopPlayback());
    _sendJson({'type': 'response.cancel'});
    _clearInputAudioBuffer();
    if (_history.isNotEmpty && _history.last['role'] == 'assistant') {
      _history.removeLast();
    }
    _assistantBuffer = '';
    _scheduleMicUnmute();
    _setStatus(RoleplayVoiceStatus.listening);
  }
}
