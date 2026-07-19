import 'package:flutter/foundation.dart';

import '../config/roleplay_ai_provider.dart';
import 'roleplay_realtime_session.dart';
import 'roleplay_session.dart';

/// Factory motore vocale roleplay.
///
/// CreditCalc usa **solo Realtime** — nessuna alternativa GPT/STT.
abstract final class RoleplaySessionFactory {
  /// Legge e normalizza `aiProvider` (solo per log/compatibilità dati).
  static String resolveProvider(Map<String, dynamic> simulationData) {
    return RoleplayAiProvider.normalize(
      simulationData['aiProvider'],
    );
  }

  /// Motore attivo: sempre Realtime.
  static String activeEngine(String normalizedProvider) {
    return RoleplayAiProvider.realtime;
  }

  static bool willUseRealtimeLater(String normalizedProvider) => true;

  static RoleplaySession create({
    required String aiProvider,
    required VoidCallback onStateChanged,
    required void Function(String message) onError,
    required bool Function() isContextActive,
  }) {
    return RoleplayRealtimeSession(
      onStateChanged: onStateChanged,
      onError: onError,
      isContextActive: isContextActive,
    );
  }
}
