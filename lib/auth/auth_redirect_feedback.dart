/// Messaggio da mostrare sulla login dopo un redirect (es. consensi rifiutati).
abstract final class AuthRedirectFeedback {
  static String? _pending;

  static void setMessage(String message) {
    _pending = message;
  }

  static String? consumeMessage() {
    final message = _pending;
    _pending = null;
    return message;
  }
}
