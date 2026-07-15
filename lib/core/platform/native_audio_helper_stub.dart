/// Fallback quando la piattaforma audio non è disponibile.
class NativeAudioHelper {
  NativeAudioHelper._();

  static Future<void> startRecording() async {
    throw UnsupportedError('Registrazione audio non supportata su questa piattaforma.');
  }

  static Future<List<int>> stopRecording() async => [];

  static Future<void> playRecording({String? path}) async {}

  static Future<void> disposePlayer() async {}
}
