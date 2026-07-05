/// Configurazione host per i blocchi sezione (Planet web vs CreditCalc app).
abstract final class SectionLockConfig {
  /// Es. `planet_web`, `calc_store`, `calc_desktop`.
  static String platformChannel = 'unknown';

  /// Titolo utente per messaggi di occupazione sezione.
  static String? titleFor(String sectionKey) => switch (sectionKey) {
        'repayment_plan' => 'Piano di rientro',
        'balance_write_off' => 'Saldo e stralcio',
        'commission_collections' => 'Incassi in provvigioni',
        'nav:creditors' => 'Creditori',
        'nav:develop' => 'Sviluppa',
        'nav:commissions' => 'Provvigioni',
        'nav:itinerary' => 'Itinerario',
        'nav:subscription' => 'Abbonamento',
        'itinerary:appointments' => 'Appuntamenti',
        'itinerary:activities' => 'Attività',
        'itinerary:reminders' => 'Promemoria',
        'itinerary:map' => 'Pianificazione territoriale',
        'itinerary:history' => 'Storico visite',
        'tools:sync' => 'Sincronizza',
        'tools:settings' => 'Impostazioni',
        'develop:backoffice' => 'Riscontro backoffice',
        'develop:installment_monitor' => 'Monitoraggio rata',
        'develop:debtor_contact' => 'WhatsApp e email',
        'develop:building_lookup' => 'Ricerca per indirizzo',
        'develop:normative_search' => 'Ricerca normativa',
        'develop:phone_analysis' => 'Analisi telefonata',
        'develop:calculator' => 'Calcolatrice',
        'commissions:statistics' => 'Statistiche provvigioni',
        'commissions:entry' => 'Inserisci provvigioni',
        'commissions:settings' => 'Imposta provvigioni',
        _ when sectionKey.startsWith('creditor:') => 'Dettaglio creditore',
        _ when sectionKey.startsWith('commission_entry:') => 'Incasso provvigioni',
        _ when sectionKey.startsWith('commission_settings:') =>
          'Impostazioni provvigioni',
        _ => null,
      };

  /// Sezioni con occupazione su `credit_calc_sessions/{userId}`.
  static bool isSupported(String sectionKey) => titleFor(sectionKey) != null;
}
