import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

/// Diagnostica PCM16 LE mono per Roleplay Realtime (pre-invio OpenAI).
class RoleplayPcmPipelineProbe {
  RoleplayPcmPipelineProbe({
    required this.tag,
    required this.declaredSampleRate,
    this.captureSeconds = 3,
    this.logFirstChunks = 10,
  });

  final String tag;
  final int declaredSampleRate;
  final int captureSeconds;
  final int logFirstChunks;

  final BytesBuilder _capture = BytesBuilder(copy: false);
  final List<int> _chunkSizes = <int>[];
  DateTime? _firstChunkAt;
  DateTime? _lastChunkAt;
  int _chunkIndex = 0;
  int _totalBytes = 0;
  int _oddChunks = 0;
  int _emptyChunks = 0;
  int _peak = 0;
  bool _captureDone = false;
  bool _rateLogged = false;
  String? _wavPath;

  int get captureTargetBytes =>
      declaredSampleRate * 2 * captureSeconds; // s16 mono

  String? get wavPath => _wavPath;

  void setWavPath(String path) => _wavPath = path;

  void ingest(List<int> pcmChunk) {
    if (!kDebugMode) return;
    final now = DateTime.now();
    _firstChunkAt ??= now;
    _lastChunkAt = now;

    final n = pcmChunk.length;
    _chunkIndex++;
    _totalBytes += n;
    if (n == 0) {
      _emptyChunks++;
    }
    if (n.isOdd) {
      _oddChunks++;
    }

    if (_chunkIndex <= logFirstChunks) {
      final durMs = n <= 0
          ? 0
          : ((n / 2) / declaredSampleRate * 1000);
      final peak = _peakOf(pcmChunk);
      if (peak > _peak) _peak = peak;
      debugPrint(
        'RoleplayAudio probe[$tag] chunk#$_chunkIndex: '
        'bytes=$n duration≈${durMs.toStringAsFixed(1)}ms '
        'peak=$peak odd=${n.isOdd} empty=${n == 0}',
      );
      if (n > 0 && n < 32) {
        debugPrint(
          'RoleplayAudio probe[$tag] WARN chunk molto corto '
          '(possibile buffer incompleto)',
        );
      }
    } else {
      final peak = _peakOf(pcmChunk);
      if (peak > _peak) _peak = peak;
    }

    if (_chunkSizes.length < logFirstChunks) {
      _chunkSizes.add(n);
    }

    // Stima sample rate reale dai byte/s dopo ~1s di cattura.
    if (!_rateLogged &&
        _firstChunkAt != null &&
        now.difference(_firstChunkAt!).inMilliseconds >= 1000) {
      _rateLogged = true;
      final elapsedSec =
          now.difference(_firstChunkAt!).inMilliseconds / 1000.0;
      final bytesPerSec = _totalBytes / elapsedSec;
      final inferredRate = (bytesPerSec / 2).round(); // s16 mono
      final ratio = inferredRate / declaredSampleRate;
      debugPrint(
        'RoleplayAudio probe[$tag] rate check: '
        'declared=${declaredSampleRate}Hz '
        'inferred≈${inferredRate}Hz '
        'bytes/s≈${bytesPerSec.toStringAsFixed(0)} '
        'ratio=${ratio.toStringAsFixed(2)} '
        '(atteso 1.0 se PCM16 mono alla rate dichiarata)',
      );
      if (ratio > 1.7 && ratio < 2.3) {
        debugPrint(
          'RoleplayAudio probe[$tag] SOSPETTO: stream ~2x '
          '(es. 48 kHz etichettato come 24 kHz) → ricampionare prima dell\'invio',
        );
      } else if (ratio > 0.4 && ratio < 0.6) {
        debugPrint(
          'RoleplayAudio probe[$tag] SOSPETTO: stream ~0.5x '
          '(es. 16 kHz etichettato come 24 kHz)',
        );
      }
    }

    if (!_captureDone) {
      final remaining = captureTargetBytes - _capture.length;
      if (remaining > 0) {
        if (n <= remaining) {
          _capture.add(Uint8List.fromList(pcmChunk));
        } else {
          _capture.add(Uint8List.fromList(pcmChunk.sublist(0, remaining)));
        }
      }
      if (_capture.length >= captureTargetBytes) {
        _captureDone = true;
        debugPrint(
          'RoleplayAudio probe[$tag] cattura ${captureSeconds}s completa '
          '(${_capture.length} bytes PCM). '
          'Chiamare flushWav() per scrivere il file.',
        );
      }
    }
  }

  /// True quando i primi [captureSeconds] sono in buffer.
  bool get hasFullCapture => _captureDone || _capture.length >= captureTargetBytes;

  Uint8List pcmCaptureBytes() => _capture.toBytes();

  /// WAV PCM16 LE mono — stesso payload che andrebbe ascoltato offline.
  Uint8List buildWavBytes({int? sampleRateOverride}) {
    final pcm = pcmCaptureBytes();
    final rate = sampleRateOverride ?? declaredSampleRate;
    return buildPcm16LeMonoWav(pcm: pcm, sampleRate: rate);
  }

  void logSummary() {
    if (!kDebugMode) return;
    final elapsedMs = (_firstChunkAt == null || _lastChunkAt == null)
        ? 0
        : _lastChunkAt!.difference(_firstChunkAt!).inMilliseconds;
    debugPrint(
      'RoleplayAudio probe[$tag] summary: chunks=$_chunkIndex '
      'totalBytes=$_totalBytes elapsedMs=$elapsedMs '
      'peak=$_peak empty=$_emptyChunks odd=$_oddChunks '
      'firstChunkSizes=$_chunkSizes '
      'wav=${_wavPath ?? '(non scritto)'}',
    );
  }

  static int _peakOf(List<int> pcm) {
    var peak = 0;
    for (var i = 0; i + 1 < pcm.length; i += 2) {
      var sample = (pcm[i] & 0xff) | ((pcm[i + 1] & 0xff) << 8);
      if (sample > 32767) sample -= 65536;
      final a = sample.abs();
      if (a > peak) peak = a;
    }
    return peak;
  }
}

/// Downsample PCM16 LE mono per fattori interi (es. 48→24 = factor 2).
Uint8List downsamplePcm16LeMono(List<int> pcm, int factor) {
  if (factor <= 1 || pcm.length < 2) {
    return Uint8List.fromList(pcm);
  }
  final sampleCount = pcm.length ~/ 2;
  final outCount = sampleCount ~/ factor;
  final out = Uint8List(outCount * 2);
  for (var o = 0; o < outCount; o++) {
    final i = o * factor * 2;
    out[o * 2] = pcm[i];
    out[o * 2 + 1] = pcm[i + 1];
  }
  return out;
}

/// Resample lineare PCM16 LE mono da [fromRate] a [toRate].
Uint8List resamplePcm16LeMonoLinear({
  required List<int> pcm,
  required int fromRate,
  required int toRate,
}) {
  if (fromRate == toRate || pcm.length < 4) {
    return Uint8List.fromList(pcm);
  }
  if (fromRate == toRate * 2) {
    return downsamplePcm16LeMono(pcm, 2);
  }
  final inSamples = pcm.length ~/ 2;
  final outSamples = math.max(1, (inSamples * toRate / fromRate).round());
  final out = Int16List(outSamples);
  for (var o = 0; o < outSamples; o++) {
    final src = o * fromRate / toRate;
    final i0 = src.floor().clamp(0, inSamples - 1);
    final i1 = math.min(i0 + 1, inSamples - 1);
    final t = src - i0;
    final s0 = _readS16Le(pcm, i0 * 2);
    final s1 = _readS16Le(pcm, i1 * 2);
    out[o] = (s0 + (s1 - s0) * t).round().clamp(-32768, 32767);
  }
  return Uint8List.view(out.buffer);
}

int _readS16Le(List<int> pcm, int offset) {
  var sample = (pcm[offset] & 0xff) | ((pcm[offset + 1] & 0xff) << 8);
  if (sample > 32767) sample -= 65536;
  return sample;
}

Uint8List buildPcm16LeMonoWav({
  required List<int> pcm,
  required int sampleRate,
}) {
  final dataSize = pcm.length;
  final fileSize = 36 + dataSize;
  final bd = ByteData(44 + dataSize);
  var o = 0;
  void fourCC(String s) {
    for (var i = 0; i < 4; i++) {
      bd.setUint8(o++, s.codeUnitAt(i));
    }
  }

  fourCC('RIFF');
  bd.setUint32(o, fileSize, Endian.little);
  o += 4;
  fourCC('WAVE');
  fourCC('fmt ');
  bd.setUint32(o, 16, Endian.little);
  o += 4; // PCM chunk size
  bd.setUint16(o, 1, Endian.little);
  o += 2; // audio format PCM
  bd.setUint16(o, 1, Endian.little);
  o += 2; // mono
  bd.setUint32(o, sampleRate, Endian.little);
  o += 4;
  bd.setUint32(o, sampleRate * 2, Endian.little);
  o += 4; // byte rate
  bd.setUint16(o, 2, Endian.little);
  o += 2; // block align
  bd.setUint16(o, 16, Endian.little);
  o += 2; // bits
  fourCC('data');
  bd.setUint32(o, dataSize, Endian.little);
  o += 4;
  for (var i = 0; i < dataSize; i++) {
    bd.setUint8(o++, pcm[i] & 0xff);
  }
  return bd.buffer.asUint8List();
}
