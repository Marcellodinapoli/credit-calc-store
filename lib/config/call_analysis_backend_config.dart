/// Endpoint backend analisi telefonata (`ai.creditcore.it`).
abstract final class CallAnalysisBackendConfig {
  static const String secureHost = 'ai.creditcore.it';

  static String get httpUrl => 'https://$secureHost/call-analysis';
}
