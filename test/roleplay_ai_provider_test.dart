import 'package:credit_calc_core/credit_calc_core.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:credit_calc/config/roleplay_ai_provider.dart';
import 'package:credit_calc/services/roleplay_session_factory.dart';

void main() {
  group('RoleplayAiProvider', () {
    test('aiProvider assente → realtime (default CreditCore)', () {
      expect(RoleplayAiProvider.normalize(null), RoleplayAiProvider.realtime);
      expect(RoleplayAiProvider.normalize(''), RoleplayAiProvider.realtime);
      expect(RoleplayAiProvider.usesRealtime({}), isTrue);
    });

    test('aiProvider gpt → gpt', () {
      expect(RoleplayAiProvider.normalize('gpt'), RoleplayAiProvider.gpt);
      expect(
        RoleplayAiProvider.usesGpt({
          RoleplayConfigService.aiProviderField: 'gpt',
        }),
        isTrue,
      );
    });

    test('aiProvider hetzner → normalizzato a gpt', () {
      expect(RoleplayAiProvider.normalize('hetzner'), RoleplayAiProvider.gpt);
      expect(RoleplayAiProvider.isGpt('hetzner'), isTrue);
      expect(RoleplayAiProvider.isRealtime('hetzner'), isFalse);
    });

    test('aiProvider realtime → realtime', () {
      expect(RoleplayAiProvider.normalize('realtime'), 'realtime');
      expect(RoleplayAiProvider.isRealtime('realtime'), isTrue);
      expect(RoleplayAiProvider.isGpt('realtime'), isFalse);
    });

    test('valore sconosciuto → realtime', () {
      expect(RoleplayAiProvider.normalize('ollama'), RoleplayAiProvider.realtime);
    });
  });

  group('RoleplaySessionFactory — Fase 1', () {
    Map<String, dynamic> simulation({String? aiProvider}) => {
          if (aiProvider != null)
            RoleplayConfigService.aiProviderField: aiProvider,
          'title': 'Test',
        };

    test('simulazione senza aiProvider → motore Realtime', () {
      final resolved = RoleplaySessionFactory.resolveProvider(simulation());
      expect(resolved, RoleplayAiProvider.realtime);
      expect(
        RoleplaySessionFactory.activeEngine(resolved),
        RoleplayAiProvider.realtime,
      );
      expect(RoleplaySessionFactory.willUseRealtimeLater(resolved), isTrue);
    });

    test('simulazione gpt → motore GPT', () {
      final resolved =
          RoleplaySessionFactory.resolveProvider(simulation(aiProvider: 'gpt'));
      expect(resolved, RoleplayAiProvider.gpt);
      expect(
        RoleplaySessionFactory.activeEngine(resolved),
        RoleplayAiProvider.gpt,
      );
    });

    test('simulazione hetzner → normalizzata e motore GPT', () {
      final resolved = RoleplaySessionFactory.resolveProvider(
        simulation(aiProvider: 'hetzner'),
      );
      expect(resolved, RoleplayAiProvider.gpt);
      expect(
        RoleplaySessionFactory.activeEngine(resolved),
        RoleplayAiProvider.gpt,
      );
    });

    test('simulazione realtime → motore Realtime', () {
      final resolved = RoleplaySessionFactory.resolveProvider(
        simulation(aiProvider: 'realtime'),
      );
      expect(resolved, RoleplayAiProvider.realtime);
      expect(
        RoleplaySessionFactory.activeEngine(resolved),
        RoleplayAiProvider.realtime,
      );
      expect(RoleplaySessionFactory.willUseRealtimeLater(resolved), isTrue);
    });
  });
}
