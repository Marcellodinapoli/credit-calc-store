import 'package:flutter/foundation.dart';

import '../config/roleplay_ai_provider.dart';
import 'roleplay_gpt_session.dart';
import 'roleplay_realtime_session.dart';
import 'roleplay_session.dart';

/// Factory per istanziare il motore vocale corretto.
abstract final class RoleplaySessionFactory {
  /// Legge e normalizza `aiProvider` dalla mappa simulazione Firestore.
  static String resolveProvider(Map<String, dynamic> simulationData) {
    return RoleplayAiProvider.normalize(
      simulationData['aiProvider'],
    );
  }

  /// Motore eseguibile per il provider normalizzato.
  static String activeEngine(String normalizedProvider) {
    if (RoleplayAiProvider.isRealtime(normalizedProvider)) {
      return RoleplayAiProvider.realtime;
    }
    return RoleplayAiProvider.gpt;
  }

  static bool willUseRealtimeLater(String normalizedProvider) =>
      RoleplayAiProvider.isRealtime(normalizedProvider);

  static RoleplaySession create({
    required String aiProvider,
    required VoidCallback onStateChanged,
    required void Function(String message) onError,
    required bool Function() isContextActive,
  }) {
    if (RoleplayAiProvider.isRealtime(aiProvider)) {
      return RoleplayRealtimeSession(
        onStateChanged: onStateChanged,
        onError: onError,
        isContextActive: isContextActive,
      );
    }
    return RoleplayGptSession(
      onStateChanged: onStateChanged,
      onError: onError,
      isContextActive: isContextActive,
    );
  }
}
