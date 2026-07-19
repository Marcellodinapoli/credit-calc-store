/// Cattura microfono e riproduzione PCM16 per Realtime API.
abstract class RoleplayRealtimeAudio {
  Future<void> startMicrophone(void Function(List<int> pcmChunk) onChunk);

  Future<void> stopMicrophone();

  Future<void> playPcm16Base64Delta(String base64Delta);

  /// Svuota il buffer di riproduzione (fine risposta assistente).
  Future<void> flushPlayback();

  /// True se l'altoparlante sta ancora riproducendo (o ha coda in uscita).
  bool get isOutputActive;

  Future<void> stopPlayback();

  Future<void> dispose();
}
