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

  group('RoleplaySessionFactory — solo Realtime', () {
    Map<String, dynamic> simulation({String? aiProvider}) => {
          if (aiProvider != null)
            RoleplayConfigService.aiProviderField: aiProvider,
          'title': 'Test',
        };

    test('qualsiasi aiProvider → motore Realtime', () {
      for (final raw in ['gpt', 'hetzner', 'realtime', 'ollama']) {
        final resolved = RoleplaySessionFactory.resolveProvider(
          simulation(aiProvider: raw),
        );
        expect(
          RoleplaySessionFactory.activeEngine(resolved),
          RoleplayAiProvider.realtime,
        );
        expect(RoleplaySessionFactory.willUseRealtimeLater(resolved), isTrue);
      }
      final missing = RoleplaySessionFactory.resolveProvider(simulation());
      expect(
        RoleplaySessionFactory.activeEngine(missing),
        RoleplayAiProvider.realtime,
      );
    });
  });
}
