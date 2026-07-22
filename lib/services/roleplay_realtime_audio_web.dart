// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:js' as js;
import 'dart:js_util' as js_util;
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import 'roleplay_realtime_audio.dart';
import 'roleplay_realtime_audio_probe.dart';
import 'roleplay_realtime_audio_rates.dart';

RoleplayRealtimeAudio createRoleplayRealtimeAudio() =>
    RoleplayRealtimeAudioWeb();

class RoleplayRealtimeAudioWeb implements RoleplayRealtimeAudio {
  static const int openaiPcmRate = kRoleplayOpenAiPcmRateHz;

  html.MediaStream? _micStream;
  dynamic _audioContext;
  dynamic _micSource;
  dynamic _scriptProcessor;
  dynamic _playbackContext;
  double _playbackTime = 0;
  DateTime? _outputActiveUntil;
  void Function(List<int> pcmChunk)? _onChunk;
  int _contextSampleRate = openaiPcmRate;
  int _chunkLogCount = 0;
  Float32List _leftOver = Float32List(0);

  @override
  bool get isOutputActive {
    final until = _outputActiveUntil;
    return until != null && DateTime.now().isBefore(until);
  }

  /// Converte float32 @ contextRate → PCM16 LE mono @ 24 kHz.
  /// Se AudioContext è già 24 kHz: bypass (nessun doppio resampling).
  Uint8List _floatToPcm16At24k(Float32List input) {
    Float32List samples = input;
    if (_leftOver.isNotEmpty) {
      final merged = Float32List(_leftOver.length + input.length);
      merged.setAll(0, _leftOver);
      merged.setAll(_leftOver.length, input);
      samples = merged;
      _leftOver = Float32List(0);
    }

    final bypass =
        RoleplayAudioRateReport.shouldBypassResampler(_contextSampleRate);

    if (bypass) {
      final pcm = Int16List(samples.length);
      for (var i = 0; i < samples.length; i++) {
        final clamped = samples[i].clamp(-1.0, 1.0);
        pcm[i] = (clamped * 32767).round();
      }
      return Uint8List.view(pcm.buffer);
    }

    final ratio = _contextSampleRate / openaiPcmRate;
    final outCount = (samples.length / ratio).floor();
    if (outCount <= 0) {
      _leftOver = samples;
      return Uint8List(0);
    }
    final used = (outCount * ratio).floor();
    if (used < samples.length) {
      _leftOver = samples.sublist(used);
    }

    final pcm = Int16List(outCount);
    for (var o = 0; o < outCount; o++) {
      final src = o * ratio;
      final i0 = src.floor().clamp(0, samples.length - 1);
      final i1 = math.min(i0 + 1, samples.length - 1);
      final t = src - i0;
      final s = samples[i0] + (samples[i1] - samples[i0]) * t;
      pcm[o] = (s.clamp(-1.0, 1.0) * 32767).round();
    }
    return Uint8List.view(pcm.buffer);
  }

  @override
  Future<void> startMicrophone(void Function(List<int> pcmChunk) onChunk) async {
    _onChunk = onChunk;
    _chunkLogCount = 0;
    _leftOver = Float32List(0);
    RoleplayAudioRateReport.reset();
    _micStream = await html.window.navigator.mediaDevices
        ?.getUserMedia({'audio': true});
    if (_micStream == null) {
      throw Exception('Microfono non disponibile.');
    }

    // Preferisci 24 kHz; il browser può comunque usare 44.1/48 → resample sotto.
    try {
      _audioContext = js_util.callConstructor(
        js_util.getProperty(html.window, 'AudioContext'),
        [
          js_util.jsify({'sampleRate': openaiPcmRate}),
        ],
      );
    } catch (_) {
      _audioContext = js_util.callConstructor(
        js_util.getProperty(html.window, 'AudioContext'),
        [],
      );
    }

    _contextSampleRate =
        ((js_util.getProperty(_audioContext, 'sampleRate') as num?)
                ?.round() ??
            openaiPcmRate);

    final bypass =
        RoleplayAudioRateReport.shouldBypassResampler(_contextSampleRate);
    RoleplayAudioRateReport.reportOnce(
      platform: 'web',
      deviceSampleRateHz: _contextSampleRate,
      audioContextSampleRateHz: _contextSampleRate,
      afterResampleSampleRateHz: openaiPcmRate,
      openaiSessionSampleRateHz: kRoleplayOpenAiPcmRateHz,
      resamplerBypassed: bypass,
    );

    _micSource = js_util.callMethod(
      _audioContext,
      'createMediaStreamSource',
      [_micStream],
    );

    _scriptProcessor = js_util.callMethod(
      _audioContext,
      'createScriptProcessor',
      [4096, 1, 1],
    );

    js_util.setProperty(
      _scriptProcessor,
      'onaudioprocess',
      js.allowInterop((event) {
        final inputBuffer = js_util.getProperty(event, 'inputBuffer');
        final channelData = js_util.callMethod(
          inputBuffer,
          'getChannelData',
          [0],
        );
        final length = js_util.getProperty(channelData, 'length') as int? ?? 0;
        if (length == 0) return;

        final floats = Float32List(length);
        for (var i = 0; i < length; i++) {
          floats[i] =
              ((js_util.getProperty(channelData, i) as num?) ?? 0).toDouble();
        }

        final pcm = _floatToPcm16At24k(floats);
        if (pcm.isEmpty) return;

        if (kDebugMode && _chunkLogCount < 10) {
          _chunkLogCount++;
          final durMs = (pcm.length / 2) / openaiPcmRate * 1000;
          debugPrint(
            'RoleplayAudio web chunk#$_chunkLogCount: '
            'bytes=${pcm.length} duration≈${durMs.toStringAsFixed(1)}ms '
            'fromContextHz=$_contextSampleRate → 24kHz PCM16LE',
          );
        }

        _onChunk?.call(pcm);
      }),
    );

    js_util.callMethod(_micSource, 'connect', [_scriptProcessor]);
    js_util.callMethod(
      _scriptProcessor,
      'connect',
      [js_util.getProperty(_audioContext, 'destination')],
    );
  }

  @override
  Future<void> stopMicrophone() async {
    try {
      if (_scriptProcessor != null) {
        js_util.callMethod(_scriptProcessor, 'disconnect', []);
      }
      if (_micSource != null) {
        js_util.callMethod(_micSource, 'disconnect', []);
      }
      final tracks = _micStream?.getAudioTracks() ?? [];
      for (final track in tracks) {
        track.stop();
      }
    } catch (_) {}
    _scriptProcessor = null;
    _micSource = null;
    _micStream = null;
    _onChunk = null;
    _leftOver = Float32List(0);
  }

  @override
  Future<void> playPcm16Base64Delta(String base64Delta) async {
    try {
      final bytes = base64Decode(base64Delta);
      if (bytes.isEmpty) return;

      _playbackContext ??= js_util.callConstructor(
        js_util.getProperty(html.window, 'AudioContext'),
        [js_util.jsify({'sampleRate': openaiPcmRate})],
      );

      final sampleCount = bytes.length ~/ 2;
      if (sampleCount == 0) return;

      final audioBuffer = js_util.callMethod(
        _playbackContext,
        'createBuffer',
        [1, sampleCount, openaiPcmRate],
      );
      final channel = js_util.callMethod(audioBuffer, 'getChannelData', [0]);

      final byteData = ByteData.sublistView(Uint8List.fromList(bytes));
      for (var i = 0; i < sampleCount; i++) {
        js_util.setProperty(
          channel,
          i,
          byteData.getInt16(i * 2, Endian.little) / 32768,
        );
      }

      final source = js_util.callMethod(
        _playbackContext,
        'createBufferSource',
        [],
      );
      js_util.setProperty(source, 'buffer', audioBuffer);
      js_util.callMethod(source, 'connect', [
        js_util.getProperty(_playbackContext, 'destination'),
      ]);

      final now =
          (js_util.getProperty(_playbackContext, 'currentTime') as num?)
                  ?.toDouble() ??
              0;
      final startAt = math.max(now, _playbackTime);
      js_util.callMethod(source, 'start', [startAt]);
      _playbackTime = startAt + sampleCount / openaiPcmRate;
      final endsAt = DateTime.now().add(
        Duration(milliseconds: (sampleCount / openaiPcmRate * 1000).ceil() + 200),
      );
      if (_outputActiveUntil == null || endsAt.isAfter(_outputActiveUntil!)) {
        _outputActiveUntil = endsAt;
      }
    } catch (e) {
      if (kDebugMode) debugPrint('RoleplayRealtime playback: $e');
    }
  }

  @override
  Future<void> flushPlayback() async {
    // Su web i buffer sono già schedulati in continuo su AudioContext.
  }

  @override
  Future<void> stopPlayback() async {
    _playbackTime = 0;
    _outputActiveUntil = null;
    try {
      final ctx = _playbackContext;
      if (ctx != null) {
        js_util.callMethod(ctx, 'close', []);
      }
    } catch (_) {}
    _playbackContext = null;
  }

  @override
  Future<void> dispose() async {
    await stopMicrophone();
    await stopPlayback();
  }
}
