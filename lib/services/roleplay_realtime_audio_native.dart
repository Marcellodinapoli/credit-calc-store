import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:record/record.dart';

import 'roleplay_realtime_audio.dart';
import 'roleplay_realtime_audio_probe.dart';
import 'roleplay_realtime_audio_probe_io.dart';
import 'roleplay_realtime_audio_rates.dart';

RoleplayRealtimeAudio createRoleplayRealtimeAudio() =>
    RoleplayRealtimeAudioNative();

/// Microfono via `record` + playback PCM16 continuo via SoLoud (gapless).
///
/// Contratto OpenAI Realtime: PCM16 little-endian mono @ 24 kHz.
/// Il resampling device→24 kHz è attivo anche in Release (non solo debug).
/// Se il device è già ~24 kHz il resampler è bypassato (mai doppio passo).
class RoleplayRealtimeAudioNative implements RoleplayRealtimeAudio {
  static const int openaiPcmRate = kRoleplayOpenAiPcmRateHz;
  static const int openaiChannels = 1;
  static const int openaiBits = 16;

  final AudioRecorder _recorder = AudioRecorder();
  final SoLoud _soloud = SoLoud.instance;

  StreamSubscription<Uint8List>? _micSubscription;
  AudioSource? _stream;
  SoundHandle? _handle;
  Future<void>? _streamReady;
  final List<AudioSource> _endedStreams = <AudioSource>[];
  DateTime? _outputQueueEnd;
  DateTime? _outputActiveUntil;

  RoleplayPcmPipelineProbe? _deviceProbe;
  RoleplayPcmPipelineProbe? _outProbe;
  /// null = in calibrazione; poi true/false se serve resample verso 24 kHz.
  bool? _needsResampleTo24k;
  int _deviceSourceRateHz = openaiPcmRate;
  final BytesBuilder _calibBuffer = BytesBuilder(copy: false);
  DateTime? _calibStartedAt;
  void Function(List<int> pcmChunk)? _clientOnChunk;
  bool _wavFlushScheduled = false;
  final int _recorderRequestedHz = openaiPcmRate;

  @override
  bool get isOutputActive {
    if (_stream != null) return true;
    final until = _outputActiveUntil;
    return until != null && DateTime.now().isBefore(until);
  }

  void _noteOutputDuration(int pcmBytes) {
    final chunkMs = ((pcmBytes / 2) / openaiPcmRate * 1000).ceil();
    const echoPadMs = 150;
    final now = DateTime.now();
    final base = (_outputQueueEnd != null && _outputQueueEnd!.isAfter(now))
        ? _outputQueueEnd!
        : now;
    _outputQueueEnd = base.add(Duration(milliseconds: chunkMs));
    _outputActiveUntil =
        _outputQueueEnd!.add(const Duration(milliseconds: echoPadMs));
  }

  Future<void> _ensureEngine() async {
    if (_soloud.isInitialized) return;
    await _soloud.init(
      sampleRate: openaiPcmRate,
      bufferSize: 2048,
      channels: Channels.mono,
    );
  }

  Future<void> _ensurePlaybackStream() {
    return _streamReady ??= () async {
      await _ensureEngine();
      if (_stream != null) return;

      _stream = _soloud.setBufferStream(
        maxBufferSizeDuration: const Duration(minutes: 2),
        bufferingType: BufferingType.released,
        bufferingTimeNeeds: 0.12,
        sampleRate: openaiPcmRate,
        channels: Channels.mono,
        format: BufferType.s16le,
      );
      _handle = await _soloud.play(_stream!);
    }();
  }

  Future<void> _disposeEndedStreams() async {
    if (_endedStreams.isEmpty) return;
    final pending = List<AudioSource>.from(_endedStreams);
    _endedStreams.clear();
    for (final source in pending) {
      try {
        await _soloud.disposeSource(source);
      } catch (_) {}
    }
  }

  void _logRecorderConfig(RecordConfig config) {
    // ignore: avoid_print
    print(
      'RoleplayAudio native: RecordConfig richiesto → '
      'encoder=${config.encoder} sampleRate=${config.sampleRate} '
      'numChannels=${config.numChannels} '
      'formato=PCM16 LE mono @ ${config.sampleRate} Hz → OpenAI $openaiPcmRate Hz',
    );
  }

  /// Converte (se serve) al contratto 24 kHz. Bypass se già ~24 kHz.
  Uint8List _toOpenAiPcm(List<int> pcm) {
    if (_needsResampleTo24k != true) {
      return pcm is Uint8List ? pcm : Uint8List.fromList(pcm);
    }
    return resamplePcm16LeMonoLinear(
      pcm: pcm,
      fromRate: _deviceSourceRateHz,
      toRate: openaiPcmRate,
    );
  }

  void _emitRateReport({required bool bypassed}) {
    RoleplayAudioRateReport.reportOnce(
      platform: 'native',
      deviceSampleRateHz: _deviceSourceRateHz,
      // Su native non c'è AudioContext: usiamo la rate richiesta a `record`.
      audioContextSampleRateHz: _recorderRequestedHz,
      afterResampleSampleRateHz: openaiPcmRate,
      openaiSessionSampleRateHz: kRoleplayOpenAiPcmRateHz,
      resamplerBypassed: bypassed,
    );
  }

  void _deliverToClient(List<int> pcm24k) {
    assert(
      openaiPcmRate == kRoleplayOpenAiPcmRateHz,
      'PCM consegnato alla sessione deve essere @ $kRoleplayOpenAiPcmRateHz',
    );
    _outProbe?.ingest(pcm24k);
    _clientOnChunk?.call(pcm24k);
    if (_outProbe != null &&
        _outProbe!.hasFullCapture &&
        !_wavFlushScheduled) {
      _wavFlushScheduled = true;
      unawaited(_flushProbeWavs());
    }
  }

  Future<void> _flushProbeWavs() async {
    final device = _deviceProbe;
    final out = _outProbe;
    String? devicePath;
    String? outPath;
    if (device != null) {
      devicePath = await writeRoleplayProbeWav(
        probe: device,
        sampleRateOverride: _deviceSourceRateHz,
      );
      device.logSummary();
    }
    if (out != null) {
      outPath = await writeRoleplayProbeWav(probe: out);
      out.logSummary();
    }
    if (device != null && out != null) {
      await writeRoleplayProbeCompareNote(
        rawPath: devicePath,
        sentPath: outPath,
        rawPcm: device.pcmCaptureBytes(),
        sentPcm: out.pcmCaptureBytes(),
      );
    }
  }

  void _onRecorderChunk(Uint8List chunk) {
    _deviceProbe?.ingest(chunk);

    // Calibrazione rate (Release + Debug): stima Hz effettivi, poi un solo
    // eventuale resample → 24 kHz. Mai doppio passo.
    if (_needsResampleTo24k == null) {
      _calibStartedAt ??= DateTime.now();
      _calibBuffer.add(chunk);
      final elapsed =
          DateTime.now().difference(_calibStartedAt!).inMilliseconds;
      if (elapsed < 600 && _calibBuffer.length < openaiPcmRate * 2) {
        return;
      }
      final elapsedSec = elapsed / 1000.0;
      final inferred =
          elapsedSec > 0 ? ((_calibBuffer.length / 2) / elapsedSec).round() : 0;
      _deviceSourceRateHz = inferred > 0 ? inferred : openaiPcmRate;
      final bypass =
          RoleplayAudioRateReport.shouldBypassResampler(_deviceSourceRateHz);
      _needsResampleTo24k = !bypass;
      _emitRateReport(bypassed: bypass);

      // ignore: avoid_print
      print(
        'RoleplayAudio native: calibrazione '
        'device≈${_deviceSourceRateHz}Hz '
        'bypassResampler=$bypass '
        'action=${bypass ? 'passthrough 24k' : 'resample $_deviceSourceRateHz→$openaiPcmRate'}',
      );

      final raw = _calibBuffer.toBytes();
      _calibBuffer.clear();
      _deliverToClient(_toOpenAiPcm(raw));
      return;
    }

    _deliverToClient(_toOpenAiPcm(chunk));
  }

  @override
  Future<void> startMicrophone(void Function(List<int> pcmChunk) onChunk) async {
    if (!await _recorder.hasPermission()) {
      throw Exception('Permesso microfono negato.');
    }

    _clientOnChunk = onChunk;
    _needsResampleTo24k = null;
    _calibBuffer.clear();
    _calibStartedAt = null;
    _wavFlushScheduled = false;
    _deviceSourceRateHz = openaiPcmRate;
    RoleplayAudioRateReport.reset();
    _deviceProbe = RoleplayPcmPipelineProbe(
      tag: 'device-raw',
      declaredSampleRate: openaiPcmRate,
    );
    _outProbe = RoleplayPcmPipelineProbe(
      tag: 'to-session-24k',
      declaredSampleRate: openaiPcmRate,
    );

    const config = RecordConfig(
      encoder: AudioEncoder.pcm16bits,
      sampleRate: openaiPcmRate,
      numChannels: openaiChannels,
      echoCancel: true,
      noiseSuppress: true,
      autoGain: true,
      audioInterruption: AudioInterruptionMode.none,
    );
    _logRecorderConfig(config);

    final stream = await _recorder.startStream(config);

    await _micSubscription?.cancel();
    _micSubscription = stream.listen(
      _onRecorderChunk,
      onError: (Object e) {
        // ignore: avoid_print
        print('RoleplayAudio native: errore stream mic: $e');
      },
    );
  }

  @override
  Future<void> stopMicrophone() async {
    await _micSubscription?.cancel();
    _micSubscription = null;
    _clientOnChunk = null;
    if (_calibBuffer.length > 0) {
      final raw = _calibBuffer.toBytes();
      _calibBuffer.clear();
      // Se stop prima della fine calibrazione, assume rate richiesta.
      _needsResampleTo24k ??= false;
      _deliverToClient(_toOpenAiPcm(raw));
    }
    if (await _recorder.isRecording()) {
      await _recorder.stop();
    }
    await _flushProbeWavs();
    _deviceProbe = null;
    _outProbe = null;
    _needsResampleTo24k = null;
  }

  @override
  Future<void> playPcm16Base64Delta(String base64Delta) async {
    final pcm = base64Decode(base64Delta);
    if (pcm.isEmpty) return;

    try {
      await _ensurePlaybackStream();
      final stream = _stream;
      if (stream == null) return;
      _noteOutputDuration(pcm.length);
      _soloud.addAudioDataStream(stream, pcm);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('RoleplayRealtime playback: $e');
      }
      _streamReady = null;
      _stream = null;
      _handle = null;
    }
  }

  @override
  Future<void> flushPlayback() async {
    // Windows: setDataIsEnded mentre il BufferStream è ancora in play
    // blocca l'intera app (flutter_soloud #426). stop+dispose è sicuro.
    if (!kIsWeb && Platform.isWindows) {
      await stopPlayback();
      return;
    }

    final stream = _stream;
    _stream = null;
    _handle = null;
    _streamReady = null;
    if (stream == null) return;

    try {
      _soloud.setDataIsEnded(stream);
      _endedStreams.add(stream);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('RoleplayRealtime flush: $e');
      }
      try {
        await _soloud.disposeSource(stream);
      } catch (_) {}
    }

    unawaited(
      Future<void>.delayed(const Duration(seconds: 8), _disposeEndedStreams),
    );
  }

  @override
  Future<void> stopPlayback() async {
    final handle = _handle;
    final stream = _stream;
    _handle = null;
    _stream = null;
    _streamReady = null;
    _outputQueueEnd = null;
    _outputActiveUntil = null;

    try {
      if (handle != null) {
        await _soloud.stop(handle);
      }
    } catch (_) {}
    try {
      if (stream != null) {
        await _soloud.disposeSource(stream);
      }
    } catch (_) {}
    await _disposeEndedStreams();
  }

  @override
  Future<void> dispose() async {
    await stopMicrophone();
    await stopPlayback();
    await _recorder.dispose();
  }
}
