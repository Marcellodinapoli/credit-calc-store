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

/// Ordine crescente dei piani individuali (free → plus → enterprise).
int subscriptionPlanTier(String planId) {
  return switch (planId) {
    'enterprise' => 2,
    'plus' => 1,
    _ => 0,
  };
}

/// Ordine crescente dei piani aziendali.
int companySubscriptionPlanTier(String planId) {
  return switch (planId) {
    'enterprise' || 'azienda' => 4,
    'professional' => 3,
    'business' => 2,
    'starter' || 'plus' => 1,
    _ => 0,
  };
}

int subscriptionPlanTierForAudience(
  String planId, {
  required bool isCompany,
}) {
  return isCompany
      ? companySubscriptionPlanTier(planId)
      : subscriptionPlanTier(planId);
}

String normalizeCompanyPlanId(String planId) {
  return switch (planId) {
    'azienda' => 'enterprise',
    'plus' => 'starter',
    _ => planId,
  };
}

/// Collaboratori work attivi consentiti per piano aziendale.
int companyCollaboratorLimitForPlan(String planId) {
  return switch (normalizeCompanyPlanId(planId)) {
    'starter' => 10,
    'business' => 25,
    'professional' => 50,
    'enterprise' => 100,
    _ => 2,
  };
}

String subscriptionPlanLabel(String? planId) {
  return switch (planId) {
    'starter' => 'Starter',
    'business' => 'Business',
    'professional' => 'Professional',
    'plus' => 'Plus',
    'enterprise' => 'Enterprise',
    'azienda' => 'Azienda',
    _ => 'Gratis',
  };
}

/// Piani commerciali mostrati nell'area «Il mio piano» delle aziende.
List<SubscriptionPlanOption> companySubscriptionPlans() {
  return const [
    SubscriptionPlanOption(
      id: 'free',
      name: 'FREE',
      price: 'Gratuito',
      description:
          'Fino a 2 collaboratori.\n\n'
          'Accesso piattaforma, 1 corso, formazione base, Warm-Up AI '
          'e 10 RolePlay AI mensili. Ideale per provare CreditCore.',
    ),
    SubscriptionPlanOption(
      id: 'starter',
      name: 'STARTER',
      price: '39 €/mese',
      description:
          'Fino a 10 collaboratori · Offerta Fondatori.\n\n'
          'Recruiting, formazione online, quiz, pianificazione, Warm-Up AI, '
          'RolePlay AI e dashboard manager.',
      availableNow: true,
    ),
    SubscriptionPlanOption(
      id: 'business',
      name: 'BUSINESS',
      price: '79 €/mese',
      description:
          'Fino a 25 collaboratori · Offerta Fondatori.\n\n'
          'Tutte le funzionalità Starter, gestione team ampliata '
          'e report avanzati.',
      availableNow: true,
    ),
    SubscriptionPlanOption(
      id: 'professional',
      name: 'PROFESSIONAL',
      price: '149 €/mese',
      description:
          'Fino a 50 collaboratori · Offerta Fondatori.\n\n'
          'Tutte le funzionalità Business, monitoraggio avanzato formazione '
          'e dashboard complete.',
      availableNow: true,
    ),
    SubscriptionPlanOption(
      id: 'enterprise',
      name: 'ENTERPRISE',
      price: '249 €/mese',
      description:
          'Fino a 100 collaboratori · Offerta Fondatori.\n\n'
          'Tutte le funzionalità Professional, priorità supporto '
          'e configurazioni personalizzate.',
      availableNow: true,
    ),
  ];
}

SubscriptionPlanOption? companySubscriptionPlanForId(String planId) {
  final normalized = switch (planId) {
    'azienda' => 'enterprise',
    'plus' => 'starter',
    _ => planId,
  };
  for (final plan in companySubscriptionPlans()) {
    if (plan.id == normalized) return plan;
  }
  return null;
}

/// Piano unico mostrato agli account azienda (area personale).
const companyDedicatedSubscriptionPlan = SubscriptionPlanOption(
  id: 'azienda',
  name: 'AZIENDA',
  price: 'Prezzo su richiesta',
  description:
      'Soluzione completa per team e organizzazioni. Workspace '
      'aziendale con gestione ruoli (admin, supervisor, dipendenti), '
      'pubblicazione offerte di lavoro, gestione candidati, '
      'assegnazione attività e monitoraggio performance tramite '
      'dashboard dedicate ai supervisor.',
  availableNow: false,
);

bool isCompanySubscriptionAudience(String registerType) =>
    registerType == 'company';

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
        availableNow: true,
      ),
      SubscriptionPlanOption(
        id: 'enterprise',
        name: 'Enterprise',
        price: '€9,99 / mese',
        description:
            'Soluzione avanzata per organizzazioni. Ruoli, supervisor, '
            'dashboard performance e priorità sulle funzioni aziendali.',
        availableNow: true,
      ),
    ];
  }

  return const [
    SubscriptionPlanOption(
      id: 'free',
      name: 'Gratis',
      price: '€0',
      description:
          'Uso base per testare la piattaforma.\n\n'
          '3 corsi attivi · 10 quiz/mese · 5 Warm-up/mese · '
          '2 Roleplay/mese · 3 contestazioni/mese · 1 piano di rientro '
          '(simulazione) · 1 saldo/stralcio · 2 itinerari/mese · '
          '5 creditori · 1 schema provvigioni · 3 candidature/mese.',
    ),
    SubscriptionPlanOption(
      id: 'plus',
      name: 'Plus',
      price: '€4,99 / mese',
      description:
          'Uso personale completo con limiti medi-alti.\n\n'
          'Fino a 50 corsi attivi · 200 quiz/mese · 100 Warm-up · '
          '80 Roleplay · 50 contestazioni · 20 piani di rientro · '
          '15 saldi/stralci · 20 itinerari · 200 creditori · '
          'storico provvigioni completo · 50 candidature/mese.\n\n'
          'Avviso al raggiungimento dell\'80% dei limiti.',
      availableNow: true,
    ),
    SubscriptionPlanOption(
      id: 'enterprise',
      name: 'Enterprise',
      price: '€9,99 / mese',
      description:
          'Uso intensivo quasi senza limiti operativi.\n\n'
          'Corsi, quiz, Warm-up, Roleplay, contestazioni, piani di '
          'rientro, saldi/stralci, itinerari, creditori, provvigioni e '
          'candidature illimitati (fair use). Analytics provvigioni avanzate.',
      availableNow: true,
    ),
  ];
}
