import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:record/record.dart';

import 'roleplay_realtime_audio.dart';

RoleplayRealtimeAudio createRoleplayRealtimeAudio() =>
    RoleplayRealtimeAudioNative();

/// Microfono via `record` + playback PCM16 continuo via SoLoud (gapless).
class RoleplayRealtimeAudioNative implements RoleplayRealtimeAudio {
  final AudioRecorder _recorder = AudioRecorder();
  final SoLoud _soloud = SoLoud.instance;

  StreamSubscription<Uint8List>? _micSubscription;
  AudioSource? _stream;
  SoundHandle? _handle;
  Future<void>? _streamReady;
  final List<AudioSource> _endedStreams = <AudioSource>[];
  DateTime? _outputActiveUntil;

  @override
  bool get isOutputActive {
    if (_stream != null || _endedStreams.isNotEmpty) return true;
    final until = _outputActiveUntil;
    return until != null && DateTime.now().isBefore(until);
  }

  void _noteOutputDuration(int pcmBytes) {
    final ms = ((pcmBytes / 2) / 24000 * 1000).ceil() + 200;
    final until = DateTime.now().add(Duration(milliseconds: ms));
    if (_outputActiveUntil == null || until.isAfter(_outputActiveUntil!)) {
      _outputActiveUntil = until;
    }
  }

  Future<void> _ensureEngine() async {
    if (_soloud.isInitialized) return;
    await _soloud.init(
      sampleRate: 24000,
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
        // ~120 ms di jitter buffer: continuo senza ritardo lungo.
        bufferingTimeNeeds: 0.12,
        sampleRate: 24000,
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

  @override
  Future<void> startMicrophone(void Function(List<int> pcmChunk) onChunk) async {
    if (!await _recorder.hasPermission()) {
      throw Exception('Permesso microfono negato.');
    }

    final stream = await _recorder.startStream(
      const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: 24000,
        numChannels: 1,
        echoCancel: true,
        noiseSuppress: true,
        autoGain: true,
        audioInterruption: AudioInterruptionMode.none,
      ),
    );

    await _micSubscription?.cancel();
    _micSubscription = stream.listen((chunk) => onChunk(chunk));
  }

  @override
  Future<void> stopMicrophone() async {
    await _micSubscription?.cancel();
    _micSubscription = null;
    if (await _recorder.isRecording()) {
      await _recorder.stop();
    }
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
    final stream = _stream;
    // Non stoppare: lascia finire la coda PCM già in buffer.
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

    // Cleanup ritardato dopo che la frase è tipicamente finita.
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
