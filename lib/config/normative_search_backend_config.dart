/// Endpoint backend ricerca normativa (`ai.creditcore.it`).
abstract final class NormativeSearchBackendConfig {
  static const String secureHost = 'ai.creditcore.it';

  static String get httpUrl => 'https://$secureHost/normative-search';
}
