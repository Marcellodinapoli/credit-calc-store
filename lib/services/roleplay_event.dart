import 'roleplay_voice_status.dart';

/// Eventi emessi da qualsiasi motore di sessione roleplay.
sealed class RoleplayEvent {
  const RoleplayEvent();
}

class StatusEvent extends RoleplayEvent {
  const StatusEvent(this.status);

  final RoleplayVoiceStatus status;
}

class TranscriptEvent extends RoleplayEvent {
  const TranscriptEvent({
    required this.speaker,
    required this.text,
    this.isFinal = true,
  });

  /// `consulente` o `debitore`.
  final String speaker;
  final String text;
  final bool isFinal;
}

class ErrorEvent extends RoleplayEvent {
  const ErrorEvent(this.message);

  final String message;
}
