import 'package:credit_calc_core/credit_calc_core.dart';

/// Motore AI per simulazione roleplay (campo Firestore `aiProvider`).
abstract final class RoleplayAiProvider {
  static const gpt = RoleplayConfigService.openAiProvider;
  static const realtime = 'realtime';

  /// Default CreditCore: simulazioni vocali Realtime se il campo manca.
  static const defaultProvider = realtime;

  /// Alias legacy Firestore (normalizzato a GPT).
  static const _legacyGptAlias = 'hetzner';

  static String normalize(dynamic raw) {
    if (raw == null || raw.toString().trim().isEmpty) {
      return defaultProvider;
    }
    final value = raw.toString().toLowerCase().trim();
    return switch (value) {
      realtime => realtime,
      _legacyGptAlias => gpt,
      gpt => gpt,
      _ => defaultProvider,
    };
  }

  static bool isRealtime(String provider) => normalize(provider) == realtime;

  static bool isGpt(String provider) => normalize(provider) == gpt;

  static bool usesGpt(Map<String, dynamic> data) =>
      isGpt(normalize(data[RoleplayConfigService.aiProviderField]));

  static bool usesRealtime(Map<String, dynamic> data) =>
      isRealtime(normalize(data[RoleplayConfigService.aiProviderField]));
}
