/// Messaggi di errore login tra [PostLoginValidation] e [LoginPage].
abstract final class AuthController {
  static String? pendingError;

  static String? consumeError() {
    final message = pendingError;
    pendingError = null;
    return message;
  }
}
