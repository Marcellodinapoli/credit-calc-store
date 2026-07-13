import 'roleplay_event.dart';
import 'roleplay_voice_status.dart';

/// Contratto comune per i motori vocali roleplay (GPT, Realtime, …).
abstract class RoleplaySession {
  Stream<RoleplayEvent> get events;

  List<Map<String, String>> get history;

  bool get isActive;

  RoleplayVoiceStatus get voiceStatus;

  Future<void> init();

  Future<void> start({
    required Map<String, dynamic> simulationData,
    required String sessionId,
  });

  Future<void> stop();

  void dispose();
}
