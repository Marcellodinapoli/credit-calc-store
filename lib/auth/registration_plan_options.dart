class RegistrationPlanOption {
  final String id;
  final String name;
  final String price;
  final String description;
  final bool availableNow;

  const RegistrationPlanOption({
    required this.id,
    required this.name,
    required this.price,
    required this.description,
    this.availableNow = true,
  });
}

List<RegistrationPlanOption> registrationPlansForType(String registerType) {
  final isCompany = registerType == 'company';
  if (isCompany) {
    return const [
      RegistrationPlanOption(
        id: 'free',
        name: 'Gratis',
        price: '€0',
        description:
            'Workspace aziendale base per iniziare. Funzioni essenziali '
            'con limiti su team, recruiting e strumenti avanzati.',
      ),
      RegistrationPlanOption(
        id: 'plus',
        name: 'Plus',
        price: '€4,99 / mese',
        description:
            'Workspace completo per piccoli team. Recruiting, gestione '
            'candidati e strumenti operativi con storico e salvataggio dati.',
        availableNow: false,
      ),
      RegistrationPlanOption(
        id: 'enterprise',
        name: 'Enterprise',
        price: '€9,99 / mese',
        description:
            'Soluzione avanzata per organizzazioni. Ruoli, supervisor, '
            'dashboard performance e priorità sulle funzioni aziendali.',
        availableNow: false,
      ),
    ];
  }

  return const [
    RegistrationPlanOption(
      id: 'free',
      name: 'Gratis',
      price: '€0',
      description:
          'Accesso base alla piattaforma per uso personale. Funzioni '
          'limitate per test e utilizzo occasionale.',
    ),
    RegistrationPlanOption(
      id: 'plus',
      name: 'Plus',
      price: '€4,99 / mese',
      description:
          'Accesso completo alle funzionalità principali. Utilizzo '
          'illimitato dei servizi core, storico attività e salvataggio dati.',
      availableNow: false,
    ),
    RegistrationPlanOption(
      id: 'enterprise',
      name: 'Enterprise',
      price: '€9,99 / mese',
      description:
          'Piano professionale con analisi, personalizzazione dei flussi '
          'e maggiore controllo sui dati per utilizzo intensivo.',
      availableNow: false,
    ),
  ];
}
