import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

/// Contratto fisso verso OpenAI Realtime (input PCM).
const int kRoleplayOpenAiPcmRateHz = 24000;

/// Tolleranza per considerare "già a 24 kHz" (bypass resampler).
const int kRoleplayRateBypassToleranceHz = 1500;

/// Report definitivo dei 4 sample rate (attivo anche in Release via [print]/[developer.log]).
class RoleplayAudioRateReport {
  RoleplayAudioRateReport._();

  static bool _reported = false;

  static void reset() => _reported = false;

  /// Emesso una sola volta per sessione microfono.
  static void reportOnce({
    required String platform,
    required int deviceSampleRateHz,
    required int audioContextSampleRateHz,
    required int afterResampleSampleRateHz,
    required int openaiSessionSampleRateHz,
    required bool resamplerBypassed,
  }) {
    if (_reported) return;
    _reported = true;

    final bypassConsistent = !resamplerBypassed ||
        _near24k(deviceSampleRateHz) ||
        _near24k(audioContextSampleRateHz);

    final afterMatchesSession =
        afterResampleSampleRateHz == openaiSessionSampleRateHz;
    final sessionIs24k = openaiSessionSampleRateHz == kRoleplayOpenAiPcmRateHz;
    final afterIs24k = afterResampleSampleRateHz == kRoleplayOpenAiPcmRateHz;

    final coherent = afterMatchesSession &&
        sessionIs24k &&
        afterIs24k &&
        bypassConsistent;

    final line = 'RoleplayAudio RATES [$platform] '
        'device=${deviceSampleRateHz}Hz '
        'audioContext=${audioContextSampleRateHz}Hz '
        'afterResample=${afterResampleSampleRateHz}Hz '
        'openaiSession=${openaiSessionSampleRateHz}Hz '
        'resamplerBypassed=$resamplerBypassed '
        'coherent=$coherent';

    // Visibile anche in Release (debugPrint viene rimosso/ottimizzato).
    // ignore: avoid_print
    print(line);
    developer.log(line, name: 'RoleplayAudio');

    assert(
      coherent,
      'RoleplayAudio rate incoerenti: $line. '
      'Il PCM inviato a input_audio_buffer.append deve essere @ '
      '$kRoleplayOpenAiPcmRateHz Hz come dichiarato in session.update.',
    );

    if (!coherent) {
      // ignore: avoid_print
      print(
        'RoleplayAudio RATES ERROR: buffer PCM e session.update non allineati. '
        'Correggere resampling prima di append.',
      );
    }
  }

  static bool _near24k(int hz) =>
      (hz - kRoleplayOpenAiPcmRateHz).abs() <= kRoleplayRateBypassToleranceHz;

  /// True se il resampler deve essere saltato (già ~24 kHz).
  static bool shouldBypassResampler(int sourceHz) => _near24k(sourceHz);
}
