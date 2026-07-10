import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'public_plan_limits.dart';
import 'public_plan_limits_config_service.dart';
import 'subscription_plan_options.dart';

typedef PublicPlanLimitsAdminVerifier = Future<bool> Function({
  bool forceRefresh,
});

enum PublicPlanLimitsAudience { users, companies }

/// Salvataggio e serializzazione form piani (BackOffice app + web).
abstract final class PublicPlanLimitsAdminService {
  static const planIds = PublicPlanLimitsConfigService.publicPlanIds;
  static const companyPlanIds = PublicPlanLimitsConfigService.companyPlanIds;

  static void applyPlansConfig({
    required Map<String, dynamic>? plans,
    required void Function(String planId, Map<String, dynamic> payload) onPlan,
  }) {
    for (final planId in planIds) {
      onPlan(planId, buildPlanFormPayload(planId, plans?[planId]));
    }
  }

  static void applyCompanyPlansConfig({
    required Map<String, dynamic>? plans,
    required void Function(String planId, Map<String, dynamic> payload) onPlan,
  }) {
    for (final planId in companyPlanIds) {
      onPlan(planId, buildCompanyPlanFormPayload(planId, plans?[planId]));
    }
  }

  static String _normalizeCompanyPlanId(String planId) =>
      normalizeCompanyPlanId(planId);

  static Map<String, dynamic> buildCompanyPlanFormPayload(
    String planId,
    dynamic raw,
  ) {
    final normalized = _normalizeCompanyPlanId(planId);
    final display = companySubscriptionPlanForId(normalized);
    final defaultLimit = companyCollaboratorLimitForPlan(normalized);
    final rawMap = raw is Map<String, dynamic>
        ? raw
        : raw is Map
            ? Map<String, dynamic>.from(raw)
            : null;

    final rawLines = rawMap?['limitLines'];
    final storedLines = rawLines is List
        ? rawLines
            .map((e) => e.toString().trim())
            .where((line) => line.isNotEmpty)
            .toList()
        : <String>[];

    final storedLimit = rawMap?['collaboratorLimit'];
    final collaboratorLimit = storedLimit is int
        ? storedLimit
        : storedLimit is num
            ? storedLimit.toInt()
            : defaultLimit;

    return {
      'tierLabel': (rawMap?['tierLabel'] ??
              display?.name ??
              subscriptionPlanLabel(normalized))
          .toString(),
      'name': (rawMap?['name'] ?? display?.name ?? subscriptionPlanLabel(normalized))
          .toString(),
      'price': (rawMap?['price'] ?? display?.price ?? 'Gratuito').toString(),
      'description':
          (rawMap?['description'] ?? display?.description ?? '').toString(),
      'limitLinesText': storedLines.isNotEmpty
          ? storedLines.join('\n')
          : 'Fino a $collaboratorLimit collaboratori',
      'availableNow': rawMap?['availableNow'] is bool
          ? rawMap!['availableNow'] as bool
          : display?.availableNow ?? normalized == 'free',
      'collaboratorLimit': '$collaboratorLimit',
    };
  }

  static Map<String, dynamic> buildCompanyFirestorePlanPayload(
    String planId,
    Map<String, dynamic> payload,
  ) {
    final normalized = _normalizeCompanyPlanId(planId);
    final defaultLimit = companyCollaboratorLimitForPlan(normalized);
    final rawLimit = (payload['collaboratorLimit'] as String? ?? '').trim();
    final collaboratorLimit =
        int.tryParse(rawLimit) ?? defaultLimit;

    return {
      'tierLabel': (payload['tierLabel'] as String? ?? '').trim(),
      'name': (payload['name'] as String? ?? '').trim(),
      'price': (payload['price'] as String? ?? '').trim(),
      'description': (payload['description'] as String? ?? '').trim(),
      'limitLines': parseLimitLinesText(payload['limitLinesText'] as String?),
      'availableNow': payload['availableNow'] == true,
      'collaboratorLimit': collaboratorLimit,
    };
  }

  static Map<String, String> generateTextsForCompanyPlan(
    String planId,
    Map<String, dynamic> payload,
  ) {
    final normalized = _normalizeCompanyPlanId(planId);
    final display = companySubscriptionPlanForId(normalized);
    final rawLimit = (payload['collaboratorLimit'] as String? ?? '').trim();
    final collaboratorLimit =
        int.tryParse(rawLimit) ?? companyCollaboratorLimitForPlan(normalized);
    final intro = (display?.description ?? '')
        .split('\n\n')
        .first
        .split('\n')
        .first
        .trim();

    return {
      if (intro.isNotEmpty) 'description': intro,
      'limitLinesText': 'Fino a $collaboratorLimit collaboratori',
    };
  }

  static Map<String, dynamic> buildPlanFormPayload(
    String planId,
    dynamic raw,
  ) {
    final defaults = defaultPublicPlanLimitsForPlan(planId);
    final display = defaultPublicSubscriptionPlanForId(planId);
    final rawMap = raw is Map<String, dynamic>
        ? raw
        : raw is Map
            ? Map<String, dynamic>.from(raw)
            : null;
    final limits = rawMap != null
        ? PublicPlanLimitsFirestore.mergeFromMap(defaults, rawMap)
        : defaults;

    final rawLines = rawMap?['limitLines'];
    final storedLines = rawLines is List
        ? rawLines
            .map((e) => e.toString().trim())
            .where((line) => line.isNotEmpty)
            .toList()
        : <String>[];

    final payload = <String, dynamic>{
      'tierLabel':
          (rawMap?['tierLabel'] ?? defaultPublicPlanTierLabel(planId)).toString(),
      'name': (rawMap?['name'] ?? display.name).toString(),
      'price': (rawMap?['price'] ?? display.price).toString(),
      'description': (rawMap?['description'] ?? display.description).toString(),
      'limitLinesText': storedLines.isNotEmpty
          ? storedLines.join('\n')
          : buildPublicPlanLimitListItems(limits, planId).join('\n'),
      'availableNow': rawMap?['availableNow'] is bool
          ? rawMap!['availableNow'] as bool
          : display.availableNow,
      'enforcement': limits.enforcement,
      'unlimitedCommissionHistory': limits.unlimitedCommissionHistory,
      'advancedCommissionAnalytics': limits.advancedCommissionAnalytics,
      'limits': limits,
    };

    for (final spec in publicPlanLimitFieldSpecs) {
      final value = readPublicPlanLimitField(limits, spec.key);
      payload['field:${spec.key}'] = value == null ? '' : '$value';
    }

    return payload;
  }

  static PublicPlanLimits limitsFromPayload(
    String planId,
    Map<String, dynamic> payload,
  ) {
    final defaults = defaultPublicPlanLimitsForPlan(planId);
    return PublicPlanLimitsFirestore.mergeFromMap(
      defaults,
      buildFirestorePlanPayload(planId, payload),
    );
  }

  static Map<String, dynamic> buildFirestorePlanPayload(
    String planId,
    Map<String, dynamic> payload,
  ) {
    final result = <String, dynamic>{
      'tierLabel': (payload['tierLabel'] as String? ?? '').trim(),
      'name': (payload['name'] as String? ?? '').trim(),
      'price': (payload['price'] as String? ?? '').trim(),
      'description': (payload['description'] as String? ?? '').trim(),
      'limitLines': parseLimitLinesText(payload['limitLinesText'] as String?),
      'availableNow': payload['availableNow'] == true,
      'enforcement':
          (payload['enforcement'] as PublicPlanEnforcement?)?.name ??
              PublicPlanEnforcement.hard.name,
      'unlimitedCommissionHistory':
          payload['unlimitedCommissionHistory'] == true,
      'advancedCommissionAnalytics':
          payload['advancedCommissionAnalytics'] == true,
    };

    for (final spec in publicPlanLimitFieldSpecs) {
      final raw = (payload['field:${spec.key}'] as String? ?? '').trim();
      result[spec.key] = raw.isEmpty ? null : int.tryParse(raw);
    }

    return result;
  }

  static List<String> parseLimitLinesText(String? text) {
    return (text ?? '')
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
  }

  static Map<String, String> generateTextsForPlan(
    String planId,
    Map<String, dynamic> payload,
  ) {
    final limits = limitsFromPayload(planId, payload);
    return {
      'description': buildPublicPlanDescriptionFromLimits(limits, planId),
      'limitLinesText':
          buildPublicPlanLimitListItems(limits, planId).join('\n'),
    };
  }

  static Map<String, Map<String, dynamic>> defaultPlansFirestorePayload() {
    return {
      for (final planId in planIds)
        planId: buildFirestorePlanPayload(
          planId,
          buildPlanFormPayload(planId, null),
        ),
    };
  }

  static Future<void> savePlans(
    Map<String, Map<String, dynamic>> plans, {
    Map<String, Map<String, dynamic>>? companyPlans,
    required PublicPlanLimitsAdminVerifier verifyAdmin,
  }) async {
    if (!await verifyAdmin(forceRefresh: true)) {
      throw StateError('Accesso negato');
    }

    final uid = FirebaseAuth.instance.currentUser?.uid;
    await FirebaseFirestore.instance
        .collection('settings')
        .doc(PublicPlanLimitsConfigService.docId)
        .set({
      'plans': plans,
      if (companyPlans != null) 'companyPlans': companyPlans,
      'updatedAt': FieldValue.serverTimestamp(),
      if (uid != null) 'updatedBy': uid,
    }, SetOptions(merge: true));
  }
}
