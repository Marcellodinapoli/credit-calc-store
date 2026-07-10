import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'public_plan_limits.dart';
import 'subscription_plan_options.dart';

/// Limiti piano da BackOffice (`settings/plan_limits`).
abstract final class PublicPlanLimitsConfigService {
  static const docId = 'plan_limits';

  static const publicPlanIds = ['free', 'plus', 'enterprise'];
  static const companyPlanIds = [
    'free',
    'starter',
    'business',
    'professional',
    'enterprise',
  ];

  static Map<String, dynamic>? _plansConfig;
  static Map<String, dynamic>? _companyPlansConfig;
  static StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _subscription;
  static final StreamController<void> _configChanges =
      StreamController<void>.broadcast();
  static final StreamController<Map<String, dynamic>?> _plansController =
      StreamController<Map<String, dynamic>?>.broadcast();
  static final StreamController<({Map<String, dynamic>? users, Map<String, dynamic>? companies})>
      _adminPlansBundleController =
      StreamController<({Map<String, dynamic>? users, Map<String, dynamic>? companies})>.broadcast();

  static const _serverGet = GetOptions(source: Source.server);

  static DocumentReference<Map<String, dynamic>> get _doc =>
      FirebaseFirestore.instance.collection('settings').doc(docId);

  /// Emesso quando i limiti su Firestore cambiano.
  static Stream<void> get onConfigChanged => _configChanges.stream;

  static void start() {
    _subscription?.cancel();
    _subscription = _doc.snapshots(includeMetadataChanges: true).listen(
      (snapshot) {
        if (!_isAuthoritativeSnapshot(snapshot)) return;
        _applyDocument(snapshot.data());
      },
      onError: (_, __) {},
    );
  }

  static bool _isAuthoritativeSnapshot(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    return snapshot.metadata.hasPendingWrites ||
        !snapshot.metadata.isFromCache;
  }

  static void _applyDocument(Map<String, dynamic>? data) {
    final plans = _readPlans(data);
    final companyPlans = _readCompanyPlans(data);
    _plansConfig = plans;
    _companyPlansConfig = companyPlans;
    if (!_plansController.isClosed) _plansController.add(plans);
    if (!_adminPlansBundleController.isClosed) {
      _adminPlansBundleController.add((users: plans, companies: companyPlans));
    }
    if (!_configChanges.isClosed) _configChanges.add(null);
  }

  static void stop() {
    _subscription?.cancel();
    _subscription = null;
    _plansConfig = null;
    _companyPlansConfig = null;
  }

  /// Stream tempo reale dei piani (include pending write dopo salvataggio).
  static Stream<Map<String, dynamic>?> watchPlansConfig() {
    start();
    return Stream.multi((controller) {
      if (_plansConfig != null) {
        controller.add(_plansConfig);
      }
      final sub = _plansController.stream.listen(
        controller.add,
        onError: controller.addError,
      );
      controller.onCancel = sub.cancel;
    });
  }

  /// Attende il caricamento limiti dal server Firestore.
  static Future<void> ensureLoaded({
    Duration timeout = const Duration(seconds: 8),
  }) async {
    start();
    try {
      final snapshot = await _doc.get(_serverGet).timeout(timeout);
      _applyDocument(snapshot.data());
    } catch (_) {}
  }

  /// Stream BackOffice: piani utenti e aziende da `settings/plan_limits`.
  static Stream<({Map<String, dynamic>? users, Map<String, dynamic>? companies})>
      watchAdminPlansBundle() {
    start();
    return Stream.multi((controller) {
      controller.add((users: _plansConfig, companies: _companyPlansConfig));
      final sub = _adminPlansBundleController.stream.listen(
        controller.add,
        onError: controller.addError,
      );
      controller.onCancel = sub.cancel;
    });
  }

  static Future<({Map<String, dynamic>? users, Map<String, dynamic>? companies})>
      fetchAdminPlansBundle() async {
    try {
      final snapshot = await _doc.get(_serverGet);
      final data = snapshot.data();
      return (users: _readPlans(data), companies: _readCompanyPlans(data));
    } catch (_) {
      return (users: null, companies: null);
    }
  }

  static Map<String, dynamic>? _readPlans(Map<String, dynamic>? data) {
    final plans = data?['plans'];
    if (plans is Map<String, dynamic>) return plans;
    if (plans is Map) return Map<String, dynamic>.from(plans);
    return null;
  }

  static Map<String, dynamic>? _readCompanyPlans(Map<String, dynamic>? data) {
    final plans = data?['companyPlans'];
    if (plans is Map<String, dynamic>) return plans;
    if (plans is Map) return Map<String, dynamic>.from(plans);
    return null;
  }

  static String _normalizePlanId(String planId) => switch (planId) {
        'plus' => 'plus',
        'enterprise' => 'enterprise',
        _ => 'free',
      };

  static PublicPlanLimits limitsForPlan(String planId) {
    final normalized = _normalizePlanId(planId);
    final defaults = defaultPublicPlanLimitsForPlan(normalized);
    final raw = _plansConfig?[normalized];
    if (raw is Map<String, dynamic>) {
      return PublicPlanLimitsFirestore.mergeFromMap(defaults, raw);
    }
    if (raw is Map) {
      return PublicPlanLimitsFirestore.mergeFromMap(
        defaults,
        Map<String, dynamic>.from(raw),
      );
    }
    return defaults;
  }

  static List<String>? _readLimitLines(dynamic raw) {
    if (raw is! List) return null;
    final lines = raw
        .map((e) => e.toString().trim())
        .where((line) => line.isNotEmpty)
        .toList();
    return lines.isEmpty ? null : lines;
  }

  /// Righe elenco salvate in BackOffice (`limitLines`), se presenti.
  static List<String>? storedLimitLinesForPlan(String planId) {
    final normalized = _normalizePlanId(planId);
    final raw = _plansConfig?[normalized];
    if (raw is! Map) return null;
    final map = raw is Map<String, dynamic>
        ? raw
        : Map<String, dynamic>.from(raw);
    return _readLimitLines(map['limitLines']);
  }

  /// Intro card da descrizione BackOffice (primo paragrafo).
  static String planIntroForDisplay(String planId) {
    final normalized = _normalizePlanId(planId);
    final raw = _plansConfig?[normalized];
    if (raw is Map) {
      final map =
          raw is Map<String, dynamic> ? raw : Map<String, dynamic>.from(raw);
      final desc = _readString(map['description']);
      if (desc != null && desc.isNotEmpty) {
        return desc.split('\n\n').first.split('\n').first.trim();
      }
    }
    return defaultPublicSubscriptionPlanForId(normalized)
        .description
        .split('\n\n')
        .first
        .split('\n')
        .first
        .trim();
  }

  /// Righe elenco in card: BackOffice se salvate, altrimenti dai limiti effettivi.
  static List<String> limitLinesForDisplay(String planId) {
    final stored = storedLimitLinesForPlan(planId);
    if (stored != null && stored.isNotEmpty) return stored;
    return buildPublicPlanLimitListItems(limitsForPlan(planId), planId);
  }

  /// Lettura singola dal server (BackOffice).
  static Future<Map<String, dynamic>?> fetchPlansConfig() async {
    try {
      final snapshot = await _doc.get(_serverGet);
      return _readPlans(snapshot.data());
    } catch (_) {
      return null;
    }
  }

  static List<SubscriptionPlanOption> subscriptionPlansForPublic() {
    return [
      for (final id in publicPlanIds) publicPlanOptionForId(id),
    ];
  }

  static SubscriptionPlanOption publicPlanOptionForId(String planId) {
    final normalized = _normalizePlanId(planId);
    final defaults = defaultPublicSubscriptionPlanForId(normalized);
    final raw = _plansConfig?[normalized];
    if (raw is! Map) return defaults;
    final map = raw is Map<String, dynamic>
        ? raw
        : Map<String, dynamic>.from(raw);

    final availableRaw = map['availableNow'];
    final availableNow = availableRaw is bool
        ? availableRaw
        : availableRaw == null
            ? defaults.availableNow
            : availableRaw == true || availableRaw == 1;

    final limits = limitsForPlan(normalized);
    final intro = planIntroForDisplay(normalized);
    final items = limitLinesForDisplay(normalized);

    return SubscriptionPlanOption(
      id: normalized,
      name: _readString(map['name']) ?? defaults.name,
      price: _readString(map['price']) ?? defaults.price,
      description: formatPublicPlanDescriptionList(
        intro: intro,
        items: items,
        enforcement: limits.enforcement,
      ),
      availableNow: availableNow,
    );
  }

  static String publicPlanTierLabel(String planId) {
    final normalized = _normalizePlanId(planId);
    final raw = _plansConfig?[normalized];
    if (raw is Map) {
      final label = _readString(raw['tierLabel']);
      if (label != null && label.isNotEmpty) {
        return label.toUpperCase();
      }
    }
    return defaultPublicPlanTierLabel(normalized);
  }

  static String? _readString(dynamic raw) {
    final text = raw?.toString().trim();
    if (text == null || text.isEmpty) return null;
    return text;
  }
}

/// Limiti effettivi (default + override BackOffice se presenti).
PublicPlanLimits publicPlanLimitsForPlan(String planId) =>
    PublicPlanLimitsConfigService.limitsForPlan(planId);
