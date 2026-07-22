import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:credit_calc/services/roleplay_realtime_audio_probe.dart';
import 'package:credit_calc/services/roleplay_realtime_audio_rates.dart';

void main() {
  group('RoleplayAudioRateReport', () {
    setUp(RoleplayAudioRateReport.reset);

    test('bypass se già ~24 kHz', () {
      expect(RoleplayAudioRateReport.shouldBypassResampler(24000), isTrue);
      expect(RoleplayAudioRateReport.shouldBypassResampler(24100), isTrue);
      expect(RoleplayAudioRateReport.shouldBypassResampler(48000), isFalse);
      expect(RoleplayAudioRateReport.shouldBypassResampler(44100), isFalse);
      expect(RoleplayAudioRateReport.shouldBypassResampler(16000), isFalse);
    });

    test('report coerente: 48→24 con resampler attivo', () {
      RoleplayAudioRateReport.reportOnce(
        platform: 'test',
        deviceSampleRateHz: 48000,
        audioContextSampleRateHz: 48000,
        afterResampleSampleRateHz: kRoleplayOpenAiPcmRateHz,
        openaiSessionSampleRateHz: kRoleplayOpenAiPcmRateHz,
        resamplerBypassed: false,
      );
    });

    test('report coerente: già 24 kHz con bypass', () {
      RoleplayAudioRateReport.reset();
      RoleplayAudioRateReport.reportOnce(
        platform: 'test',
        deviceSampleRateHz: 24000,
        audioContextSampleRateHz: 24000,
        afterResampleSampleRateHz: kRoleplayOpenAiPcmRateHz,
        openaiSessionSampleRateHz: kRoleplayOpenAiPcmRateHz,
        resamplerBypassed: true,
      );
    });
  });

  group('resamplePcm16LeMonoLinear', () {
    Uint8List tone({required int samples, required int sampleRate}) {
      final out = Int16List(samples);
      for (var i = 0; i < samples; i++) {
        // Gradiente deterministico (non silenzio).
        out[i] = ((i % 200) - 100) * 100;
      }
      return Uint8List.view(out.buffer);
    }

    test('bypass: fromRate == toRate non altera lunghezza', () {
      final pcm = tone(samples: 2400, sampleRate: 24000);
      final out = resamplePcm16LeMonoLinear(
        pcm: pcm,
        fromRate: 24000,
        toRate: 24000,
      );
      expect(out.length, pcm.length);
    });

    test('48→24 dimezza i campioni (un solo passo)', () {
      final pcm = tone(samples: 4800, sampleRate: 48000);
      final out = resamplePcm16LeMonoLinear(
        pcm: pcm,
        fromRate: 48000,
        toRate: 24000,
      );
      expect(out.length, 4800); // 2400 samples * 2 bytes
      // Secondo passo non deve cambiare se già 24 kHz.
      final again = resamplePcm16LeMonoLinear(
        pcm: out,
        fromRate: 24000,
        toRate: 24000,
      );
      expect(again.length, out.length);
    });

    test('44.1→24 riduce i campioni senza passare da 16 kHz', () {
      final pcm = tone(samples: 4410, sampleRate: 44100);
      final out = resamplePcm16LeMonoLinear(
        pcm: pcm,
        fromRate: 44100,
        toRate: 24000,
      );
      final outSamples = out.length ~/ 2;
      expect(outSamples, closeTo(2400, 5));
    });
  });

  group('session rate contract', () {
    test('openai session rate costante = 24000', () {
      expect(kRoleplayOpenAiPcmRateHz, 24000);
    });
  });
}
