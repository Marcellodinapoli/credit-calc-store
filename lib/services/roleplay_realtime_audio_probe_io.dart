import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'roleplay_realtime_audio_probe.dart';

/// Scrive WAV di diagnostica su filesystem (solo IO / debug).
Future<String?> writeRoleplayProbeWav({
  required RoleplayPcmPipelineProbe probe,
  int? sampleRateOverride,
}) async {
  if (!kDebugMode || kIsWeb) return null;
  final pcm = probe.pcmCaptureBytes();
  if (pcm.isEmpty) {
    debugPrint('RoleplayAudio probe[${probe.tag}] WAV skip: pcm vuoto');
    return null;
  }
  try {
    final dir = await getTemporaryDirectory();
    final ts = DateTime.now().toIso8601String().replaceAll(':', '-');
    final rate = sampleRateOverride ?? probe.declaredSampleRate;
    final path =
        '${dir.path}${Platform.pathSeparator}roleplay_${probe.tag}_$ts.wav';
    final wav = buildPcm16LeMonoWav(pcm: pcm, sampleRate: rate);
    await File(path).writeAsBytes(wav, flush: true);
    probe.setWavPath(path);
    debugPrint(
      'RoleplayAudio probe[${probe.tag}] WAV scritto: $path '
      '(${pcm.length} bytes PCM @ ${rate}Hz s16le mono) — '
      'ascoltalo e confrontalo con la trascrizione OpenAI',
    );
    return path;
  } catch (e) {
    debugPrint('RoleplayAudio probe[${probe.tag}] WAV error: $e');
    return null;
  }
}

Future<void> writeRoleplayProbeCompareNote({
  required String? rawPath,
  required String? sentPath,
  required Uint8List rawPcm,
  required Uint8List sentPcm,
}) async {
  if (!kDebugMode || kIsWeb) return;
  final same = listEquals(rawPcm, sentPcm);
  debugPrint(
    'RoleplayAudio probe COMPARE device-raw vs to-session-24k: '
    'rawBytes=${rawPcm.length} outBytes=${sentPcm.length} '
    'identical=$same '
    'deviceWav=$rawPath outWav=$sentPath',
  );
  if (!same) {
    debugPrint(
      'RoleplayAudio probe COMPARE: differiscono (atteso se downsample 48→24). '
      'Ascolta device-raw (rate device) e to-session-24k (ciò che va in sessione). '
      'Confronta poi con sent-openai.wav (ciò che è partito verso Realtime).',
    );
  } else {
    debugPrint(
      'RoleplayAudio probe COMPARE: device-raw == to-session-24k '
      '(nessun resample locale). Confronta con sent-openai.wav.',
    );
  }
}
