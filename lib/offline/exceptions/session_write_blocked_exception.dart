/// Salvataggio rifiutato: la sessione CreditCalc è su un altro dispositivo.
class SessionWriteBlockedException implements Exception {
  SessionWriteBlockedException([this.message = _defaultMessage]);

  static const _defaultMessage =
      'La sessione CreditCalc è attiva su un altro dispositivo. '
      'Chiudi e riapri CreditCalc qui, poi scegli «Continua qui».';

  final String message;

  @override
  String toString() => message;
}
