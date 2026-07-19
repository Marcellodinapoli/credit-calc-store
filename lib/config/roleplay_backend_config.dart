/// Ruolo storico: non più usato dal flusso Realtime produzione.
///
/// Produzione: Firebase `roleplayRealtimeToken` + `wss://api.openai.com/v1/realtime`.
@Deprecated('Usare roleplayRealtimeToken + OpenAI diretto')
abstract final class RoleplayBackendConfig {
  static const String openAiRealtimeHost = 'api.openai.com';
}
