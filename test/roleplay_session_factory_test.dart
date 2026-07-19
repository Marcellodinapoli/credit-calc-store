import 'package:flutter_test/flutter_test.dart';

import 'package:credit_calc/services/roleplay_session_factory.dart';
import 'package:credit_calc/config/roleplay_ai_provider.dart';

void main() {
  group('RoleplaySessionFactory', () {
    test('activeEngine è sempre realtime (anche con gpt)', () {
      expect(
        RoleplaySessionFactory.activeEngine(RoleplayAiProvider.gpt),
        RoleplayAiProvider.realtime,
      );
      expect(
        RoleplaySessionFactory.activeEngine(RoleplayAiProvider.realtime),
        RoleplayAiProvider.realtime,
      );
      expect(
        RoleplaySessionFactory.willUseRealtimeLater(RoleplayAiProvider.gpt),
        isTrue,
      );
    });
  });
}
