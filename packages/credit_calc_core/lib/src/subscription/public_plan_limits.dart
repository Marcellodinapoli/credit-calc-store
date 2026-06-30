/// Area funzionale del limite (per BackOffice e consumi).
enum PublicPlanLimitArea {
  creditForm,
  creditCalc,
  creditJob,
}

String publicPlanLimitAreaLabel(PublicPlanLimitArea area) => switch (area) {
      PublicPlanLimitArea.creditForm => 'CreditForm (formazione)',
      PublicPlanLimitArea.creditCalc => 'CreditCalc (operatività)',
      PublicPlanLimitArea.creditJob => 'CreditJob (lavoro)',
    };

/// Specifica campo limite — unica fonte per BackOffice, consumi e testi piano.
class PublicPlanLimitFieldSpec {
  const PublicPlanLimitFieldSpec({
    required this.key,
    required this.label,
    required this.area,
    required this.readValue,
    this.periodHint,
    this.descriptionLabel,
  });

  final String key;
  final String label;
  final PublicPlanLimitArea area;
  final String? periodHint;
  /// Etichetta breve per descrizione piano (es. «itinerari/mese»).
  final String? descriptionLabel;
  final int? Function(PublicPlanLimits limits) readValue;
}

const publicPlanLimitFieldSpecs = <PublicPlanLimitFieldSpec>[
  PublicPlanLimitFieldSpec(
    key: 'activeCourses',
    label: 'Corsi attivi',
    area: PublicPlanLimitArea.creditForm,
    periodHint: 'totali',
    descriptionLabel: 'corsi attivi',
    readValue: _readActiveCourses,
  ),
  PublicPlanLimitFieldSpec(
    key: 'monthlyQuiz',
    label: 'Quiz',
    area: PublicPlanLimitArea.creditForm,
    periodHint: 'al mese',
    descriptionLabel: 'quiz/mese',
    readValue: _readMonthlyQuiz,
  ),
  PublicPlanLimitFieldSpec(
    key: 'monthlyWarmup',
    label: 'Warm-up',
    area: PublicPlanLimitArea.creditForm,
    periodHint: 'al mese',
    descriptionLabel: 'Warm-up/mese',
    readValue: _readMonthlyWarmup,
  ),
  PublicPlanLimitFieldSpec(
    key: 'monthlyRoleplay',
    label: 'Roleplay',
    area: PublicPlanLimitArea.creditForm,
    periodHint: 'al mese',
    descriptionLabel: 'Roleplay/mese',
    readValue: _readMonthlyRoleplay,
  ),
  PublicPlanLimitFieldSpec(
    key: 'monthlyContestation',
    label: 'Contestazioni',
    area: PublicPlanLimitArea.creditForm,
    periodHint: 'al mese',
    descriptionLabel: 'contestazioni/mese',
    readValue: _readMonthlyContestation,
  ),
  PublicPlanLimitFieldSpec(
    key: 'monthlyRepaymentPlan',
    label: 'Piani di rientro',
    area: PublicPlanLimitArea.creditCalc,
    periodHint: 'al mese',
    descriptionLabel: 'piani di rientro',
    readValue: _readMonthlyRepaymentPlan,
  ),
  PublicPlanLimitFieldSpec(
    key: 'monthlyBalanceWriteOff',
    label: 'Saldi e stralci',
    area: PublicPlanLimitArea.creditCalc,
    periodHint: 'al mese',
    descriptionLabel: 'saldi/stralci',
    readValue: _readMonthlyBalanceWriteOff,
  ),
  PublicPlanLimitFieldSpec(
    key: 'monthlyItinerary',
    label: 'Generazioni itinerario',
    area: PublicPlanLimitArea.creditCalc,
    periodHint: 'al mese',
    descriptionLabel: 'itinerari/mese',
    readValue: _readMonthlyItinerary,
  ),
  PublicPlanLimitFieldSpec(
    key: 'totalCreditors',
    label: 'Creditori',
    area: PublicPlanLimitArea.creditCalc,
    periodHint: 'totali',
    descriptionLabel: 'creditori',
    readValue: _readTotalCreditors,
  ),
  PublicPlanLimitFieldSpec(
    key: 'totalCommissionSchemas',
    label: 'Schemi provvigioni',
    area: PublicPlanLimitArea.creditCalc,
    periodHint: 'totali',
    descriptionLabel: 'schemi provvigioni',
    readValue: _readTotalCommissionSchemas,
  ),
  PublicPlanLimitFieldSpec(
    key: 'monthlyJobApplications',
    label: 'Candidature lavoro',
    area: PublicPlanLimitArea.creditJob,
    periodHint: 'al mese',
    descriptionLabel: 'candidature/mese',
    readValue: _readMonthlyJobApplications,
  ),
];

int? _readActiveCourses(PublicPlanLimits l) => l.activeCourses;
int? _readMonthlyQuiz(PublicPlanLimits l) => l.monthlyQuiz;
int? _readMonthlyWarmup(PublicPlanLimits l) => l.monthlyWarmup;
int? _readMonthlyRoleplay(PublicPlanLimits l) => l.monthlyRoleplay;
int? _readMonthlyContestation(PublicPlanLimits l) => l.monthlyContestation;
int? _readMonthlyRepaymentPlan(PublicPlanLimits l) => l.monthlyRepaymentPlan;
int? _readMonthlyBalanceWriteOff(PublicPlanLimits l) => l.monthlyBalanceWriteOff;
int? _readMonthlyItinerary(PublicPlanLimits l) => l.monthlyItinerary;
int? _readTotalCreditors(PublicPlanLimits l) => l.totalCreditors;
int? _readTotalCommissionSchemas(PublicPlanLimits l) => l.totalCommissionSchemas;
int? _readMonthlyJobApplications(PublicPlanLimits l) => l.monthlyJobApplications;

int? readPublicPlanLimitField(PublicPlanLimits limits, String key) {
  for (final spec in publicPlanLimitFieldSpecs) {
    if (spec.key == key) return spec.readValue(limits);
  }
  return null;
}

List<PublicPlanLimitFieldSpec> publicPlanLimitFieldsForArea(
  PublicPlanLimitArea area,
) =>
    publicPlanLimitFieldSpecs.where((s) => s.area == area).toList();

/// Righe elenco limiti per card piano (ordine fasi CreditForm → CreditCalc → CreditJob).
List<String> buildPublicPlanLimitListItems(
  PublicPlanLimits limits,
  String planId,
) {
  if (limits.enforcement == PublicPlanEnforcement.fairUse) {
    return [
      'Corsi, quiz, Warm-up, Roleplay e contestazioni illimitati',
      'Piani di rientro, saldi/stralci e itinerari illimitati',
      'Creditori, provvigioni e candidature illimitati (fair use)',
      if (limits.advancedCommissionAnalytics) 'Analytics provvigioni avanzate',
    ];
  }

  final items = <String>[];
  for (final spec in publicPlanLimitFieldSpecs) {
    final value = spec.readValue(limits);
    if (value == null) continue;
    final label = spec.descriptionLabel ?? spec.label.toLowerCase();
    if (spec.key == 'monthlyRepaymentPlan' && planId == 'free' && value == 1) {
      items.add('1 piano di rientro (simulazione)');
    } else if (spec.key == 'activeCourses' && planId == 'plus') {
      items.add('Fino a $value $label');
    } else {
      items.add('$value $label');
    }
  }

  if (limits.unlimitedCommissionHistory) {
    items.add('Storico provvigioni completo');
  }

  return items;
}

/// Descrizione piano: intro + elenco puntato (sempre, ovunque viene mostrata).
String formatPublicPlanDescriptionList({
  required String intro,
  required List<String> items,
  PublicPlanEnforcement enforcement = PublicPlanEnforcement.hard,
}) {
  final buffer = StringBuffer(intro.trim());
  if (items.isNotEmpty) {
    buffer.writeln();
    buffer.writeln();
    for (final item in items) {
      buffer.writeln('• $item');
    }
  }
  if (enforcement == PublicPlanEnforcement.soft) {
    buffer
      ..writeln()
      ..write('Avviso al raggiungimento dell\'80% dei limiti.');
  }
  return buffer.toString();
}

/// Testo marketing dai limiti numerici (intro + elenco puntato).
String buildPublicPlanDescriptionFromLimits(
  PublicPlanLimits limits,
  String planId,
) {
  final intro = switch (planId) {
    'plus' => 'Uso personale completo con limiti medi-alti.',
    'enterprise' => 'Uso intensivo quasi senza limiti operativi.',
    _ => limits.enforcement == PublicPlanEnforcement.fairUse
        ? 'Uso intensivo quasi senza limiti operativi.'
        : 'Uso base per testare la piattaforma.',
  };

  return formatPublicPlanDescriptionList(
    intro: intro,
    items: buildPublicPlanLimitListItems(limits, planId),
    enforcement: limits.enforcement,
  );
}

/// Metriche conteggiate per i piani individuali (public).
enum PublicUsageMetric {
  activeCourse,
  quiz,
  warmup,
  roleplay,
  contestation,
  repaymentPlan,
  balanceWriteOff,
  itinerary,
  creditorTotal,
  commissionSchema,
  jobApplication,
}

/// Modalità di enforcement per piano.
enum PublicPlanEnforcement {
  /// FREE — blocco netto al limite.
  hard,

  /// PLUS — avviso all'80%, blocco al 100%.
  soft,

  /// ENTERPRISE — senza limiti operativi (fair use / anti-abuso futuro).
  fairUse,
}

class PublicPlanLimits {
  const PublicPlanLimits({
    required this.enforcement,
    this.activeCourses,
    this.monthlyQuiz,
    this.monthlyWarmup,
    this.monthlyRoleplay,
    this.monthlyContestation,
    this.monthlyRepaymentPlan,
    this.monthlyBalanceWriteOff,
    this.monthlyItinerary,
    this.totalCreditors,
    this.totalCommissionSchemas,
    this.monthlyJobApplications,
    this.unlimitedCommissionHistory = false,
    this.advancedCommissionAnalytics = false,
  });

  final PublicPlanEnforcement enforcement;
  final int? activeCourses;
  final int? monthlyQuiz;
  final int? monthlyWarmup;
  final int? monthlyRoleplay;
  final int? monthlyContestation;
  final int? monthlyRepaymentPlan;
  final int? monthlyBalanceWriteOff;
  final int? monthlyItinerary;
  final int? totalCreditors;
  final int? totalCommissionSchemas;
  final int? monthlyJobApplications;
  final bool unlimitedCommissionHistory;
  final bool advancedCommissionAnalytics;

  int? limitFor(PublicUsageMetric metric) => switch (metric) {
        PublicUsageMetric.activeCourse => activeCourses,
        PublicUsageMetric.quiz => monthlyQuiz,
        PublicUsageMetric.warmup => monthlyWarmup,
        PublicUsageMetric.roleplay => monthlyRoleplay,
        PublicUsageMetric.contestation => monthlyContestation,
        PublicUsageMetric.repaymentPlan => monthlyRepaymentPlan,
        PublicUsageMetric.balanceWriteOff => monthlyBalanceWriteOff,
        PublicUsageMetric.itinerary => monthlyItinerary,
        PublicUsageMetric.creditorTotal => totalCreditors,
        PublicUsageMetric.commissionSchema => totalCommissionSchemas,
        PublicUsageMetric.jobApplication => monthlyJobApplications,
      };

  bool isMonthly(PublicUsageMetric metric) => switch (metric) {
        PublicUsageMetric.creditorTotal ||
        PublicUsageMetric.commissionSchema ||
        PublicUsageMetric.activeCourse =>
          false,
        _ => true,
      };
}

PublicPlanLimits defaultPublicPlanLimitsForPlan(String planId) {
  return switch (planId) {
    'plus' => const PublicPlanLimits(
      enforcement: PublicPlanEnforcement.soft,
      activeCourses: 50,
      monthlyQuiz: 200,
      monthlyWarmup: 100,
      monthlyRoleplay: 80,
      monthlyContestation: 50,
      monthlyRepaymentPlan: 20,
      monthlyBalanceWriteOff: 15,
      monthlyItinerary: 20,
      totalCreditors: 200,
      totalCommissionSchemas: null,
      monthlyJobApplications: 50,
      unlimitedCommissionHistory: true,
    ),
    'enterprise' => const PublicPlanLimits(
      enforcement: PublicPlanEnforcement.fairUse,
      unlimitedCommissionHistory: true,
      advancedCommissionAnalytics: true,
    ),
    _ => const PublicPlanLimits(
      enforcement: PublicPlanEnforcement.hard,
      activeCourses: 3,
      monthlyQuiz: 10,
      monthlyWarmup: 5,
      monthlyRoleplay: 2,
      monthlyContestation: 3,
      monthlyRepaymentPlan: 1,
      monthlyBalanceWriteOff: 1,
      monthlyItinerary: 2,
      totalCreditors: 5,
      totalCommissionSchemas: 1,
      monthlyJobApplications: 3,
    ),
  };
}

extension PublicPlanLimitsFirestore on PublicPlanLimits {
  Map<String, dynamic> toFirestoreMap() => {
        'enforcement': enforcement.name,
        if (activeCourses != null) 'activeCourses': activeCourses,
        if (monthlyQuiz != null) 'monthlyQuiz': monthlyQuiz,
        if (monthlyWarmup != null) 'monthlyWarmup': monthlyWarmup,
        if (monthlyRoleplay != null) 'monthlyRoleplay': monthlyRoleplay,
        if (monthlyContestation != null) 'monthlyContestation': monthlyContestation,
        if (monthlyRepaymentPlan != null) 'monthlyRepaymentPlan': monthlyRepaymentPlan,
        if (monthlyBalanceWriteOff != null) 'monthlyBalanceWriteOff': monthlyBalanceWriteOff,
        if (monthlyItinerary != null) 'monthlyItinerary': monthlyItinerary,
        if (totalCreditors != null) 'totalCreditors': totalCreditors,
        if (totalCommissionSchemas != null) 'totalCommissionSchemas': totalCommissionSchemas,
        if (monthlyJobApplications != null) 'monthlyJobApplications': monthlyJobApplications,
        'unlimitedCommissionHistory': unlimitedCommissionHistory,
        'advancedCommissionAnalytics': advancedCommissionAnalytics,
      };

  static PublicPlanLimits mergeFromMap(
    PublicPlanLimits defaults,
    Map<String, dynamic> overrides,
  ) {
    return PublicPlanLimits(
      enforcement: _parseEnforcement(overrides['enforcement']) ??
          defaults.enforcement,
      activeCourses: overrides.containsKey('activeCourses')
          ? _nullableInt(overrides['activeCourses'])
          : defaults.activeCourses,
      monthlyQuiz: overrides.containsKey('monthlyQuiz')
          ? _nullableInt(overrides['monthlyQuiz'])
          : defaults.monthlyQuiz,
      monthlyWarmup: overrides.containsKey('monthlyWarmup')
          ? _nullableInt(overrides['monthlyWarmup'])
          : defaults.monthlyWarmup,
      monthlyRoleplay: overrides.containsKey('monthlyRoleplay')
          ? _nullableInt(overrides['monthlyRoleplay'])
          : defaults.monthlyRoleplay,
      monthlyContestation: overrides.containsKey('monthlyContestation')
          ? _nullableInt(overrides['monthlyContestation'])
          : defaults.monthlyContestation,
      monthlyRepaymentPlan: overrides.containsKey('monthlyRepaymentPlan')
          ? _nullableInt(overrides['monthlyRepaymentPlan'])
          : defaults.monthlyRepaymentPlan,
      monthlyBalanceWriteOff: overrides.containsKey('monthlyBalanceWriteOff')
          ? _nullableInt(overrides['monthlyBalanceWriteOff'])
          : defaults.monthlyBalanceWriteOff,
      monthlyItinerary: overrides.containsKey('monthlyItinerary')
          ? _nullableInt(overrides['monthlyItinerary'])
          : defaults.monthlyItinerary,
      totalCreditors: overrides.containsKey('totalCreditors')
          ? _nullableInt(overrides['totalCreditors'])
          : defaults.totalCreditors,
      totalCommissionSchemas: overrides.containsKey('totalCommissionSchemas')
          ? _nullableInt(overrides['totalCommissionSchemas'])
          : defaults.totalCommissionSchemas,
      monthlyJobApplications: overrides.containsKey('monthlyJobApplications')
          ? _nullableInt(overrides['monthlyJobApplications'])
          : defaults.monthlyJobApplications,
      unlimitedCommissionHistory: overrides.containsKey(
            'unlimitedCommissionHistory',
          )
          ? overrides['unlimitedCommissionHistory'] == true
          : defaults.unlimitedCommissionHistory,
      advancedCommissionAnalytics: overrides.containsKey(
            'advancedCommissionAnalytics',
          )
          ? overrides['advancedCommissionAnalytics'] == true
          : defaults.advancedCommissionAnalytics,
    );
  }

  static PublicPlanEnforcement? _parseEnforcement(dynamic raw) {
    final value = raw?.toString().trim().toLowerCase();
    return switch (value) {
      'hard' => PublicPlanEnforcement.hard,
      'soft' => PublicPlanEnforcement.soft,
      'fairuse' || 'fair_use' => PublicPlanEnforcement.fairUse,
      _ => null,
    };
  }

  static int? _nullableInt(dynamic raw) {
    if (raw == null) return null;
    if (raw is num) return raw.toInt();
    final text = raw.toString().trim();
    if (text.isEmpty) return null;
    return int.tryParse(text);
  }
}

String publicUsageMetricLabel(PublicUsageMetric metric) => switch (metric) {
      PublicUsageMetric.activeCourse => 'corsi attivi',
      PublicUsageMetric.quiz => 'quiz',
      PublicUsageMetric.warmup => 'sessioni Warm-up',
      PublicUsageMetric.roleplay => 'sessioni Roleplay',
      PublicUsageMetric.contestation => 'contestazioni',
      PublicUsageMetric.repaymentPlan => 'piani di rientro',
      PublicUsageMetric.balanceWriteOff => 'simulazioni saldo e stralcio',
      PublicUsageMetric.itinerary => 'generazioni itinerario',
      PublicUsageMetric.creditorTotal => 'creditori',
      PublicUsageMetric.commissionSchema => 'schemi provvigioni',
      PublicUsageMetric.jobApplication => 'candidature lavoro',
    };

/// Metriche con contatore solo sul dispositivo (CreditCalc operativo).
bool publicUsageMetricIsDeviceLocal(PublicUsageMetric metric) =>
    switch (metric) {
      PublicUsageMetric.creditorTotal ||
      PublicUsageMetric.commissionSchema ||
      PublicUsageMetric.repaymentPlan ||
      PublicUsageMetric.balanceWriteOff ||
      PublicUsageMetric.itinerary =>
        true,
      _ => false,
    };

/// Chiave persistenza contatori mensili locali.
String? publicUsageMonthlyStorageField(PublicUsageMetric metric) =>
    switch (metric) {
      PublicUsageMetric.repaymentPlan => 'repaymentPlan',
      PublicUsageMetric.balanceWriteOff => 'balanceWriteOff',
      PublicUsageMetric.itinerary => 'itinerary',
      _ => null,
    };
