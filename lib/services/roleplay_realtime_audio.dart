/// Cattura microfono e riproduzione PCM16 per Realtime API.
abstract class RoleplayRealtimeAudio {
  Future<void> startMicrophone(void Function(List<int> pcmChunk) onChunk);

  Future<void> stopMicrophone();

  Future<void> playPcm16Base64Delta(String base64Delta);

  Future<void> stopPlayback();

  Future<void> dispose();
}
