import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'public_plan_limits.dart';
import 'subscription_plan_options.dart';

/// Limiti piano da BackOffice (`settings/plan_limits`).
abstract final class PublicPlanLimitsConfigService {
  static const docId = 'plan_limits';

  static Map<String, dynamic>? _plansConfig;
  static StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _subscription;
  static final StreamController<void> _configChanges =
      StreamController<void>.broadcast();

  static DocumentReference<Map<String, dynamic>> get _doc =>
      FirebaseFirestore.instance.collection('settings').doc(docId);

  /// Emesso quando i limiti su Firestore cambiano (BackOffice o altro client).
  static Stream<void> get onConfigChanged => _configChanges.stream;

  static void start() {
    if (_subscription != null) return;

    unawaited(_loadFromServer());

    _subscription = _doc.snapshots().listen(
      (snapshot) {
        _plansConfig = _readPlans(snapshot.data());
        if (!_configChanges.isClosed) _configChanges.add(null);
      },
      onError: (_, __) {},
    );
  }

  static void stop() {
    _subscription?.cancel();
    _subscription = null;
    _plansConfig = null;
  }

  /// Attende il primo caricamento limiti (cache o server).
  static Future<void> ensureLoaded({
    Duration timeout = const Duration(seconds: 8),
  }) async {
    start();
    if (_plansConfig != null) return;

    try {
      await _loadFromServer().timeout(timeout);
    } on TimeoutException {
      // Usa cache locale Firestore se il server non risponde in tempo.
    }

    if (_plansConfig != null) return;

    try {
      final snapshot = await _doc.get().timeout(timeout);
      _plansConfig = _readPlans(snapshot.data());
    } catch (_) {}
  }

  static Future<void> _loadFromServer() async {
    try {
      final snapshot = await _doc.get(const GetOptions(source: Source.server));
      _plansConfig = _readPlans(snapshot.data());
    } catch (_) {}
  }

  static Map<String, dynamic>? _readPlans(Map<String, dynamic>? data) {
    final plans = data?['plans'];
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

  static Stream<Map<String, dynamic>?> watchPlansConfig() {
    return _doc.snapshots().map((snap) => _readPlans(snap.data()));
  }

  static const publicPlanIds = ['free', 'plus', 'enterprise'];

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

    return SubscriptionPlanOption(
      id: normalized,
      name: _readString(map['name']) ?? defaults.name,
      price: _readString(map['price']) ?? defaults.price,
      description: _readString(map['description']) ?? defaults.description,
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
