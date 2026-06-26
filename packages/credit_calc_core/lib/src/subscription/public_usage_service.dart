import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'public_plan_limits.dart';
import 'public_plan_limits_config_service.dart';
import 'platform_admin.dart';
import 'public_usage_local_data_access.dart';

class PublicUsageCheckResult {
  const PublicUsageCheckResult({
    required this.allowed,
    this.warning = false,
    this.message,
    this.used,
    this.limit,
    this.planId = 'free',
  });

  final bool allowed;
  final bool warning;
  final String? message;
  final int? used;
  final int? limit;
  final String planId;

  static const skipped = PublicUsageCheckResult(allowed: true);
}

/// Voce consumo per la sezione «I miei consumi».
class PlanUsageItem {
  const PlanUsageItem({
    required this.label,
    required this.used,
    this.limit,
    this.unlimited = false,
    this.periodHint,
  });

  final String label;
  final int used;
  final int? limit;
  final bool unlimited;

  /// Es. «questo mese» o «totali».
  final String? periodHint;

  double? get ratio {
    if (unlimited || limit == null || limit! <= 0) return null;
    return (used / limit!).clamp(0.0, 1.0);
  }

  int? get remaining {
    if (unlimited || limit == null) return null;
    return (limit! - used).clamp(0, limit!);
  }
}

/// Conteggio utilizzo e limiti per utenti `public` (work/azienda esclusi).
abstract final class PublicUsageService {
  static const _softWarningRatio = 0.8;

  static final _firestore = FirebaseFirestore.instance;

  static String _monthKey([DateTime? dt]) {
    final d = dt ?? DateTime.now();
    return '${d.year}-${d.month.toString().padLeft(2, '0')}';
  }

  static String _metricField(PublicUsageMetric metric) => switch (metric) {
        PublicUsageMetric.quiz => 'quiz',
        PublicUsageMetric.warmup => 'warmup',
        PublicUsageMetric.roleplay => 'roleplay',
        PublicUsageMetric.contestation => 'contestation',
        PublicUsageMetric.repaymentPlan => 'repaymentPlan',
        PublicUsageMetric.balanceWriteOff => 'balanceWriteOff',
        PublicUsageMetric.itinerary => 'itinerary',
        PublicUsageMetric.jobApplication => 'jobApplication',
        _ => '',
      };

  static DocumentReference<Map<String, dynamic>> _monthlyRef(String uid) =>
      _firestore.collection('users').doc(uid).collection('public_usage').doc('monthly');

  static Future<({String type, String planId})?> _userContext() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;
    final snap = await _firestore.collection('users').doc(uid).get();
    final data = snap.data() ?? {};
    final type = (data['type'] ?? 'public').toString().trim().toLowerCase();
    final planId = (data['subscriptionPlan'] ?? 'free').toString();
    return (type: type, planId: planId);
  }

  static bool shouldEnforceForUserType(String type) {
    final t = type.trim().toLowerCase();
    return t == 'public' || t.isEmpty;
  }

  static Future<PublicUsageCheckResult> check(
    PublicUsageMetric metric, {
    int consumeAmount = 1,
  }) async {
    if (await PlatformAdmin.isCurrentUser()) {
      return PublicUsageCheckResult.skipped;
    }
    final ctx = await _userContext();
    if (ctx == null) {
      return const PublicUsageCheckResult(
        allowed: false,
        message: 'Sessione scaduta. Effettua di nuovo l\'accesso.',
      );
    }
    if (!shouldEnforceForUserType(ctx.type)) {
      return PublicUsageCheckResult.skipped;
    }

    final limits = publicPlanLimitsForPlan(ctx.planId);
    if (limits.enforcement == PublicPlanEnforcement.fairUse) {
      return PublicUsageCheckResult(allowed: true, planId: ctx.planId);
    }

    final limit = limits.limitFor(metric);
    if (limit == null) {
      return PublicUsageCheckResult(allowed: true, planId: ctx.planId);
    }

    final used = await _readUsage(metric, limits);
    final projected = used + consumeAmount;
    final label = publicUsageMetricLabel(metric);

    if (projected > limit) {
      return PublicUsageCheckResult(
        allowed: false,
        used: used,
        limit: limit,
        planId: ctx.planId,
        message:
            'Hai raggiunto il limite del piano '
            '${_planLabel(ctx.planId)} per $label '
            '($used/$limit). Passa a un piano superiore per continuare.',
      );
    }

    if (limits.enforcement == PublicPlanEnforcement.soft &&
        projected >= (limit * _softWarningRatio).ceil()) {
      return PublicUsageCheckResult(
        allowed: true,
        warning: true,
        used: projected,
        limit: limit,
        planId: ctx.planId,
        message:
            'Stai per raggiungere il limite $label del piano '
            '${_planLabel(ctx.planId)} ($projected/$limit).',
      );
    }

    return PublicUsageCheckResult(
      allowed: true,
      used: used,
      limit: limit,
      planId: ctx.planId,
    );
  }

  static Future<void> consume(PublicUsageMetric metric, {int amount = 1}) async {
    if (await PlatformAdmin.isCurrentUser()) return;
    final ctx = await _userContext();
    if (ctx == null || !shouldEnforceForUserType(ctx.type)) return;

    final limits = publicPlanLimitsForPlan(ctx.planId);
    if (limits.enforcement == PublicPlanEnforcement.fairUse) return;
    if (limits.limitFor(metric) == null) return;

    if (publicUsageMetricIsDeviceLocal(metric)) {
      if (!limits.isMonthly(metric)) return;
      await PublicUsageLocalDataAccess.instance?.incrementMonthly(
        metric,
        amount,
      );
      return;
    }

    if (!limits.isMonthly(metric)) return;

    final uid = FirebaseAuth.instance.currentUser!.uid;
    final ref = _monthlyRef(uid);
    final field = _metricField(metric);
    if (field.isEmpty) return;

    await _firestore.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final data = snap.data() ?? {};
      final monthKey = _monthKey();
      var counts = Map<String, dynamic>.from(
        (data['counts'] as Map?)?.cast<String, dynamic>() ?? {},
      );
      if (data['monthKey'] != monthKey) {
        counts = {};
      }
      final current = _readInt(counts[field]);
      counts[field] = current + amount;
      tx.set(ref, {
        'monthKey': monthKey,
        'counts': counts,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
  }

  /// Azzera i contatori mensili del piano (coupon limiti da backoffice).
  static Future<void> resetMonthlyUsage() async {
    if (await PlatformAdmin.isCurrentUser()) return;
    final ctx = await _userContext();
    if (ctx == null || !shouldEnforceForUserType(ctx.type)) return;

    final uid = FirebaseAuth.instance.currentUser!.uid;
    await _monthlyRef(uid).set({
      'monthKey': _monthKey(),
      'counts': <String, int>{},
      'resetAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await PublicUsageLocalDataAccess.instance?.resetMonthlyCounts();
  }

  static Future<int> _readUsage(
    PublicUsageMetric metric,
    PublicPlanLimits limits,
  ) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return 0;

    if (publicUsageMetricIsDeviceLocal(metric)) {
      final local = PublicUsageLocalDataAccess.instance;
      if (local == null) return 0;
      if (metric == PublicUsageMetric.creditorTotal) {
        return local.countCreditors(uid);
      }
      if (metric == PublicUsageMetric.commissionSchema) {
        return local.countCommissionSchemas(uid);
      }
      return local.readMonthlyCount(metric);
    }

    if (metric == PublicUsageMetric.activeCourse) {
      return _countActiveCourses(uid);
    }
    if (limits.isMonthly(metric)) {
      return _readMonthlyCount(uid, metric);
    }
    return 0;
  }

  static Future<int> _readMonthlyCount(String uid, PublicUsageMetric metric) async {
    final field = _metricField(metric);
    if (field.isEmpty) return 0;
    final snap = await _monthlyRef(uid).get();
    final data = snap.data() ?? {};
    if (data['monthKey'] != _monthKey()) return 0;
    final counts = data['counts'] as Map<String, dynamic>? ?? {};
    return _readInt(counts[field]);
  }

  static Future<int> _countActiveCourses(String uid) async {
    final snap = await _firestore
        .collection('userProgress')
        .doc(uid)
        .collection('courses')
        .get();
    var active = 0;
    for (final doc in snap.docs) {
      final progress = doc.data()['progress'];
      final p = progress is num ? progress.toInt() : 0;
      if (p < 100) active++;
    }
    return active;
  }

  static int _readInt(dynamic raw) {
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    return 0;
  }

  static String _planLabel(String planId) => switch (planId) {
        'plus' => 'Plus',
        'enterprise' => 'Enterprise',
        _ => 'Gratis',
      };

  static bool allowsAdvancedCommissionHistory(String planId) {
    final limits = publicPlanLimitsForPlan(planId);
    return limits.unlimitedCommissionHistory;
  }

  static Future<PublicUsageCheckResult> checkCommissionHistoryAccess() async {
    if (await PlatformAdmin.isCurrentUser()) {
      return PublicUsageCheckResult.skipped;
    }
    final ctx = await _userContext();
    if (ctx == null) {
      return const PublicUsageCheckResult(
        allowed: false,
        message: 'Sessione scaduta. Effettua di nuovo l\'accesso.',
      );
    }
    if (!shouldEnforceForUserType(ctx.type)) {
      return PublicUsageCheckResult.skipped;
    }
    final limits = publicPlanLimitsForPlan(ctx.planId);
    if (limits.unlimitedCommissionHistory) {
      return PublicUsageCheckResult(allowed: true, planId: ctx.planId);
    }
    return PublicUsageCheckResult(
      allowed: false,
      planId: ctx.planId,
      message:
          'Lo storico provvigioni è disponibile dal piano Plus. '
          'Con il piano Gratis puoi configurare un solo schema base.',
    );
  }

  static Future<PublicUsageCheckResult> checkCommissionAnalyticsAccess() async {
    if (await PlatformAdmin.isCurrentUser()) {
      return PublicUsageCheckResult.skipped;
    }
    final ctx = await _userContext();
    if (ctx == null) {
      return const PublicUsageCheckResult(
        allowed: false,
        message: 'Sessione scaduta. Effettua di nuovo l\'accesso.',
      );
    }
    if (!shouldEnforceForUserType(ctx.type)) {
      return PublicUsageCheckResult.skipped;
    }
    final limits = publicPlanLimitsForPlan(ctx.planId);
    if (limits.advancedCommissionAnalytics) {
      return PublicUsageCheckResult(allowed: true, planId: ctx.planId);
    }
    return PublicUsageCheckResult(
      allowed: false,
      planId: ctx.planId,
      message:
          'Le analytics avanzate provvigioni sono incluse nel piano Enterprise.',
    );
  }

  static Future<List<PlanUsageItem>> loadUsageItems() async {
    if (await PlatformAdmin.isCurrentUser()) return const [];
    final ctx = await _userContext();
    if (ctx == null || !shouldEnforceForUserType(ctx.type)) {
      return const [];
    }
    return loadUsageItemsForPlan(ctx.planId);
  }

  static Future<List<PlanUsageItem>> loadUsageItemsForPlan(String planId) async {
    try {
      return await _buildUsageItems(planId);
    } catch (_) {
      return fallbackUsageItems(planId);
    }
  }

  /// Limiti del piano con conteggio a zero (fallback se Firestore non risponde).
  static List<PlanUsageItem> fallbackUsageItems(String planId) {
    final limits = publicPlanLimitsForPlan(planId);
    if (limits.enforcement == PublicPlanEnforcement.fairUse) {
      return const [
        PlanUsageItem(
          label: 'Utilizzo piano',
          used: 0,
          unlimited: true,
          periodHint: 'Fair use — senza limiti operativi',
        ),
      ];
    }

    const metrics = <(PublicUsageMetric metric, String? period)>[
      (PublicUsageMetric.activeCourse, null),
      (PublicUsageMetric.quiz, 'questo mese'),
      (PublicUsageMetric.warmup, 'questo mese'),
      (PublicUsageMetric.roleplay, 'questo mese'),
      (PublicUsageMetric.contestation, 'questo mese'),
      (PublicUsageMetric.repaymentPlan, 'questo mese'),
      (PublicUsageMetric.balanceWriteOff, 'questo mese'),
      (PublicUsageMetric.itinerary, 'questo mese'),
      (PublicUsageMetric.creditorTotal, 'totali'),
      (PublicUsageMetric.commissionSchema, 'totali'),
      (PublicUsageMetric.jobApplication, 'questo mese'),
    ];

    final items = <PlanUsageItem>[];
    for (final entry in metrics) {
      final limit = limits.limitFor(entry.$1);
      if (limit == null) continue;
      items.add(
        PlanUsageItem(
          label: publicUsageMetricLabel(entry.$1),
          used: 0,
          limit: limit,
          periodHint: entry.$2,
        ),
      );
    }
    return items;
  }

  /// Aggiorna i consumi al cambio piano o al consumo mensile.
  static Stream<List<PlanUsageItem>> watchUsageItems() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return Stream.value(const []);

    final userRef = _firestore.collection('users').doc(uid);

    return userRef.snapshots().asyncExpand((userSnap) async* {
      if (await PlatformAdmin.isCurrentUser()) {
        yield const <PlanUsageItem>[];
        return;
      }
      final data = userSnap.data() ?? {};
      final type = (data['type'] ?? 'public').toString().trim().toLowerCase();
      if (!shouldEnforceForUserType(type)) {
        yield const <PlanUsageItem>[];
        return;
      }
      final planId = (data['subscriptionPlan'] ?? 'free').toString();
      yield* watchUsageForPlan(planId);
    });
  }

  /// Consumi per un piano specifico (si aggiorna al cambio contatori mensili).
  static Stream<List<PlanUsageItem>> watchUsageForPlan(String planId) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return Stream.value(const []);

    final monthlyRef = _monthlyRef(uid);
    final local = PublicUsageLocalDataAccess.instance;
    final planLimits = PublicPlanLimitsConfigService.onConfigChanged;

    return Stream.multi((controller) async {
      Future<void> emit() async {
        if (controller.isClosed) return;
        try {
          controller.add(await _buildUsageItems(planId));
        } catch (_) {
          if (!controller.isClosed) {
            controller.add(fallbackUsageItems(planId));
          }
        }
      }

      await emit();
      final subMonthly = monthlyRef.snapshots().listen((_) => emit());
      final subLocal = local?.changes.listen((_) => emit());
      final subLimits = planLimits.listen((_) => emit());
      controller.onCancel = () {
        subMonthly.cancel();
        subLocal?.cancel();
        subLimits.cancel();
      };
    });
  }

  static Future<List<PlanUsageItem>> _buildUsageItems(String planId) async {
    final limits = publicPlanLimitsForPlan(planId);
    if (limits.enforcement == PublicPlanEnforcement.fairUse) {
      return const [
        PlanUsageItem(
          label: 'Utilizzo piano',
          used: 0,
          unlimited: true,
          periodHint: 'Fair use — senza limiti operativi',
        ),
      ];
    }

    const metrics = <(PublicUsageMetric metric, String? period)>[
      (PublicUsageMetric.activeCourse, null),
      (PublicUsageMetric.quiz, 'questo mese'),
      (PublicUsageMetric.warmup, 'questo mese'),
      (PublicUsageMetric.roleplay, 'questo mese'),
      (PublicUsageMetric.contestation, 'questo mese'),
      (PublicUsageMetric.repaymentPlan, 'questo mese'),
      (PublicUsageMetric.balanceWriteOff, 'questo mese'),
      (PublicUsageMetric.itinerary, 'questo mese'),
      (PublicUsageMetric.creditorTotal, 'totali'),
      (PublicUsageMetric.commissionSchema, 'totali'),
      (PublicUsageMetric.jobApplication, 'questo mese'),
    ];

    final items = <PlanUsageItem>[];
    for (final entry in metrics) {
      final limit = limits.limitFor(entry.$1);
      if (limit == null) continue;
      final used = await _readUsage(entry.$1, limits);
      items.add(
        PlanUsageItem(
          label: publicUsageMetricLabel(entry.$1),
          used: used,
          limit: limit,
          periodHint: entry.$2,
        ),
      );
    }
    return items;
  }

  /// Verifica accesso a un corso (nuovo conteggio solo se non già attivo).
  static Future<PublicUsageCheckResult> checkCourseAccess(
    String courseId,
  ) async {
    if (await PlatformAdmin.isCurrentUser()) {
      return PublicUsageCheckResult.skipped;
    }
    final ctx = await _userContext();
    if (ctx == null) {
      return const PublicUsageCheckResult(
        allowed: false,
        message: 'Sessione scaduta. Effettua di nuovo l\'accesso.',
      );
    }
    if (!shouldEnforceForUserType(ctx.type)) {
      return PublicUsageCheckResult.skipped;
    }

    final limits = publicPlanLimitsForPlan(ctx.planId);
    if (limits.enforcement == PublicPlanEnforcement.fairUse) {
      return PublicUsageCheckResult(allowed: true, planId: ctx.planId);
    }

    final limit = limits.activeCourses;
    if (limit == null) {
      return PublicUsageCheckResult(allowed: true, planId: ctx.planId);
    }

    final uid = FirebaseAuth.instance.currentUser!.uid;
    final courseSnap = await _firestore
        .collection('userProgress')
        .doc(uid)
        .collection('courses')
        .doc(courseId)
        .get();
    if (courseSnap.exists) {
      final progress = courseSnap.data()?['progress'];
      final p = progress is num ? progress.toInt() : 0;
      if (p < 100) {
        return PublicUsageCheckResult(
          allowed: true,
          used: await _countActiveCourses(uid),
          limit: limit,
          planId: ctx.planId,
        );
      }
    }

    final active = await _countActiveCourses(uid);
    if (active >= limit) {
      return PublicUsageCheckResult(
        allowed: false,
        used: active,
        limit: limit,
        planId: ctx.planId,
        message:
            'Hai raggiunto il limite di $limit corsi attivi del piano '
            '${_planLabel(ctx.planId)}. Completa un corso o passa a un '
            'piano superiore.',
      );
    }

    if (limits.enforcement == PublicPlanEnforcement.soft &&
        active + 1 >= (limit * _softWarningRatio).ceil()) {
      return PublicUsageCheckResult(
        allowed: true,
        warning: true,
        used: active + 1,
        limit: limit,
        planId: ctx.planId,
        message:
            'Stai per raggiungere il limite corsi attivi del piano '
            '${_planLabel(ctx.planId)} (${active + 1}/$limit).',
      );
    }

    return PublicUsageCheckResult(
      allowed: true,
      used: active,
      limit: limit,
      planId: ctx.planId,
    );
  }
}
