/// Endpoint backend analisi telefonata (Ollama su Hetzner).
abstract final class CallAnalysisBackendConfig {
  static const String secureHost = 'ai.creditcore.it';

  static String get httpUrl => 'https://$secureHost/call-analysis';
}
