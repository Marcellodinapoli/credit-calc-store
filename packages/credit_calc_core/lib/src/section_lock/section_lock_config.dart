/// Configurazione host per i blocchi sezione (Planet web vs CreditCalc app).
abstract final class SectionLockConfig {
  /// Es. `planet_web`, `calc_store`, `calc_desktop`.
  static String platformChannel = 'unknown';

  /// Titolo utente per messaggi di occupazione sezione.
  static String? titleFor(String sectionKey) => switch (sectionKey) {
        'repayment_plan' => 'Piano di rientro',
        'balance_write_off' => 'Saldo e stralcio',
        'commission_collections' => 'Incassi in provvigioni',
        _ when sectionKey.startsWith('creditor:') => 'Dettaglio creditore',
        _ when sectionKey.startsWith('commission_entry:') => 'Incasso provvigioni',
        _ when sectionKey.startsWith('commission_settings:') =>
          'Impostazioni provvigioni',
        _ => null,
      };

  /// Sezioni con occupazione su `credit_calc_sessions/{userId}`.
  static bool isSupported(String sectionKey) => titleFor(sectionKey) != null;
}
