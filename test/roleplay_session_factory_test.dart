import 'package:flutter_test/flutter_test.dart';

import 'package:credit_calc/services/roleplay_gpt_session.dart';
import 'package:credit_calc/services/roleplay_realtime_session.dart';
import 'package:credit_calc/services/roleplay_session_factory.dart';
import 'package:credit_calc/config/roleplay_ai_provider.dart';

void main() {
  group('RoleplaySessionFactory', () {
    test('create gpt engine', () {
      final session = RoleplaySessionFactory.create(
        aiProvider: RoleplayAiProvider.gpt,
        onStateChanged: () {},
        onError: (_) {},
        isContextActive: () => true,
      );
      expect(session, isA<RoleplayGptSession>());
    });

    test('create realtime engine', () {
      final session = RoleplaySessionFactory.create(
        aiProvider: RoleplayAiProvider.realtime,
        onStateChanged: () {},
        onError: (_) {},
        isContextActive: () => true,
      );
      expect(session, isA<RoleplayRealtimeSession>());
    });
  });
}
