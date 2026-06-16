class SubscriptionPlanOption {
  final String id;
  final String name;
  final String price;
  final String description;
  final bool availableNow;

  const SubscriptionPlanOption({
    required this.id,
    required this.name,
    required this.price,
    required this.description,
    this.availableNow = true,
  });
}

/// Ordine crescente dei piani (free → plus → enterprise).
int subscriptionPlanTier(String planId) {
  return switch (planId) {
    'enterprise' => 2,
    'plus' => 1,
    _ => 0,
  };
}

String subscriptionPlanLabel(String? planId) {
  return switch (planId) {
    'plus' => 'Plus',
    'enterprise' => 'Enterprise',
    _ => 'Gratis',
  };
}

List<SubscriptionPlanOption> subscriptionPlansForType(String registerType) {
  final isCompany = registerType == 'company';
  if (isCompany) {
    return const [
      SubscriptionPlanOption(
        id: 'free',
        name: 'Gratis',
        price: '€0',
        description:
            'Workspace aziendale base per iniziare. Funzioni essenziali '
            'con limiti su team, recruiting e strumenti avanzati.',
      ),
      SubscriptionPlanOption(
        id: 'plus',
        name: 'Plus',
        price: '€4,99 / mese',
        description:
            'Workspace completo per piccoli team. Recruiting, gestione '
            'candidati e strumenti operativi con storico e salvataggio dati.',
        availableNow: false,
      ),
      SubscriptionPlanOption(
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
    SubscriptionPlanOption(
      id: 'free',
      name: 'Gratis',
      price: '€0',
      description:
          'Accesso base alla piattaforma per uso personale. Funzioni '
          'limitate per test e utilizzo occasionale.',
    ),
    SubscriptionPlanOption(
      id: 'plus',
      name: 'Plus',
      price: '€4,99 / mese',
      description:
          'Accesso completo alle funzionalità principali. Utilizzo '
          'illimitato dei servizi core, storico attività e salvataggio dati.',
      availableNow: false,
    ),
    SubscriptionPlanOption(
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
