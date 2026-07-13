import 'package:flutter_test/flutter_test.dart';

import 'package:credit_calc/services/roleplay_realtime_session_config.dart';

void main() {
  group('RoleplayRealtimeSessionConfig', () {
    test('buildSessionUpdate include prompt, practiceData e parametri', () {
      final update = RoleplayRealtimeSessionConfig.buildSessionUpdate(
        sessionId: 'sim-1',
        simulationData: {
          'prompt': 'Prompt simulazione',
          'practiceData': [
            {'label': 'Debitore', 'value': 'Rossi'},
          ],
          'difficulty': 'media',
          'personality': 'collaborativo',
          'scenarioWeights': {
            'DEBITORE': 1.0,
            'GARANTE': 0.0,
            'TERZO': 0.0,
          },
        },
      );

      expect(update['type'], 'session.update');
      final session = update['session'] as Map<String, dynamic>;
      final instructions = session['instructions'] as String;
      expect(instructions, contains('Prompt simulazione'));
      expect(instructions, contains('Debitore: Rossi'));
      expect(instructions, contains('PARAMETRI SIMULAZIONE'));
      expect(instructions, contains('DEBITORE'));
      expect(session['modalities'], ['text', 'audio']);
      expect(session['input_audio_format'], 'pcm16');
      expect(session['output_audio_format'], 'pcm16');
    });

    test('pickRole deterministico da sessionId', () {
      final first = RoleplayRealtimeSessionConfig.buildSessionUpdate(
        sessionId: 'fixed-session',
        simulationData: {
          'prompt': 'P',
          'scenarioWeights': {
            'DEBITORE': 0.0,
            'GARANTE': 1.0,
            'TERZO': 0.0,
          },
        },
      );
      final second = RoleplayRealtimeSessionConfig.buildSessionUpdate(
        sessionId: 'fixed-session',
        simulationData: {
          'prompt': 'P',
          'scenarioWeights': {
            'DEBITORE': 0.0,
            'GARANTE': 1.0,
            'TERZO': 0.0,
          },
        },
      );

      expect(first['session'], isA<Map<String, dynamic>>());
      expect(
        (first['session'] as Map)['instructions'],
        (second['session'] as Map)['instructions'],
      );
      expect(
        (first['session'] as Map)['instructions'],
        contains('GARANTE'),
      );
    });
  });
}
