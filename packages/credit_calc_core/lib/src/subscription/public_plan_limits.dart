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

PublicPlanLimits publicPlanLimitsForPlan(String planId) {
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
