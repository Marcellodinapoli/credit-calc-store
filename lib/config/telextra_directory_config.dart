/// Configurazione ricerca Telextra (backend licenziato + portali web elenchi).
abstract final class TelextraDirectoryConfig {
  static const String secureHost = 'ai.creditcore.it';

  /// Quando il backend Telextra non è deployato, resta disattivo senza errori.
  static const bool backendEnabled = false;

  static String get searchUrl => 'https://$secureHost/telextra-search';

  /// Portali web con layout ItaliaOnline nell'ecosistema elenchi Telextra.
  static const webHosts = <String>[
    'www.1188.it',
    'www.elenchitelefonici.it',
  ];

  static const webTabs = <String>['indirizzo', 'privati', 'aziende'];
}
