/// Modalità operativa CreditCalc scelta dall'utente.
enum CreditCalcMode {
  /// Comportamento attuale: solo Firebase, nessun dato locale.
  web,

  /// Database locale + sincronizzazione con Firebase.
  offlineSync,
}

extension CreditCalcModeCodec on CreditCalcMode {
  String get storageValue => name;

  static CreditCalcMode? fromStorage(String? raw) {
    return switch (raw) {
      'web' => CreditCalcMode.web,
      'offlineSync' => CreditCalcMode.offlineSync,
      _ => null,
    };
  }

  String get label => switch (this) {
        CreditCalcMode.web => 'Modalità Web',
        CreditCalcMode.offlineSync => 'Offline + Sincronizzazione',
      };

  String get description => switch (this) {
        CreditCalcMode.web =>
          'Dati sempre su Firebase. Richiede connessione internet.',
        CreditCalcMode.offlineSync =>
          'Dati sul dispositivo con sync automatica verso Firebase.',
      };
}
