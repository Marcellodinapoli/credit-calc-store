import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'subscription_plan_options.dart';

/// Sincronizza e applica il limite collaboratori work per piano aziendale.
abstract final class CompanyCollaboratorLimitService {
  static final _firestore = FirebaseFirestore.instance;

  static int _readInt(Map<String, dynamic>? data, String key, int fallback) {
    final raw = data?[key];
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    return fallback;
  }

  static String _planLabel(String planId) =>
      subscriptionPlanLabel(planId).toUpperCase();

  static String _baseCompanyCode(String companyCode) {
    final trimmed = companyCode.trim();
    if (trimmed.isEmpty) return trimmed;
    return trimmed.startsWith('CP-') ? trimmed : 'CP-$trimmed';
  }

  static List<String> workCodeDocIds(String companyCode) {
    final base = _baseCompanyCode(companyCode);
    return ['$base-COL', '$base-SUP'];
  }

  /// Stato utilizzo collaboratori work per l'azienda collegata all'utente corrente.
  static Stream<CompanyCollaboratorUsage?> watchCurrentCompanyUsage() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return Stream.value(null);
    return watchCompanyUsage(uid);
  }

  static Stream<CompanyCollaboratorUsage> watchCompanyUsage(String companyId) {
    return _firestore.collection('companies').doc(companyId).snapshots().map(
      (snap) {
        final data = snap.data() ?? {};
        final planId = (data['subscriptionPlan'] ?? 'free').toString();
        final limit = _readInt(
          data,
          'collaboratorLimit',
          companyCollaboratorLimitForPlan(planId),
        );
        final active = _readInt(data, 'activeWorkUsers', 0);
        return CompanyCollaboratorUsage(
          active: active,
          limit: limit,
          planId: planId,
        );
      },
    );
  }

  /// Aggiorna `collaboratorLimit` su azienda e codici work collegati.
  static Future<void> syncPlanLimitForCompany({
    required String companyId,
    required String companyCode,
    required String subscriptionPlan,
  }) async {
    final limit = companyCollaboratorLimitForPlan(subscriptionPlan);
    final batch = _firestore.batch();

    batch.set(
      _firestore.collection('companies').doc(companyId),
      {
        'collaboratorLimit': limit,
        'subscriptionPlan': subscriptionPlan,
      },
      SetOptions(merge: true),
    );

    for (final code in workCodeDocIds(companyCode)) {
      batch.set(
        _firestore.collection('work_codes').doc(code),
        {
          'collaboratorLimit': limit,
          'subscriptionPlan': subscriptionPlan,
          'companyId': companyId,
          'companyCode': _baseCompanyCode(companyCode),
        },
        SetOptions(merge: true),
      );
    }

    await batch.commit();
  }

  /// Verifica (pre-login) se il codice work consente ancora registrazioni.
  static Future<WorkRegistrationCapacity> checkWorkCodeCapacity(
    String workCode,
  ) async {
    final code = workCode.trim();
    if (code.isEmpty) {
      return const WorkRegistrationCapacity(
        allowed: false,
        message: 'Codice di accesso mancante.',
      );
    }

    final snap = await _firestore.collection('work_codes').doc(code).get();
    if (!snap.exists) {
      return const WorkRegistrationCapacity(
        allowed: false,
        message: 'Codice non valido o non attivo.',
      );
    }

    final data = snap.data() ?? {};
    final planId = (data['subscriptionPlan'] ?? 'free').toString();
    final limit = _readInt(
      data,
      'collaboratorLimit',
      companyCollaboratorLimitForPlan(planId),
    );
    final active = _readInt(data, 'activeWorkUsers', 0);
    if (active >= limit) {
      return WorkRegistrationCapacity(
        allowed: false,
        message:
            'L\'azienda ha raggiunto il limite di $limit utenti attivi '
            'previsto dal piano. Per aggiungere collaboratori è necessario '
            'un upgrade del piano.',
        limit: limit,
        active: active,
      );
    }

    return WorkRegistrationCapacity(
      allowed: true,
      limit: limit,
      active: active,
    );
  }

  /// Registra un nuovo utente work e incrementa i contatori (transazione).
  static Future<void> registerWorkUserWithLimit({
    required String companyId,
    required String companyCode,
    required DocumentReference<Map<String, dynamic>> userRef,
    required Map<String, dynamic> userData,
  }) async {
    final companyRef = _firestore.collection('companies').doc(companyId);
    final codeIds = workCodeDocIds(companyCode);
    final workCodeRefs = codeIds
        .map((id) => _firestore.collection('work_codes').doc(id))
        .toList();

    await _firestore.runTransaction((tx) async {
      final companySnap = await tx.get(companyRef);
      if (!companySnap.exists) {
        throw StateError('Azienda non trovata.');
      }

      final companyData = companySnap.data() ?? {};
      final planId =
          (companyData['subscriptionPlan'] ?? 'free').toString();
      final limit = _readInt(
        companyData,
        'collaboratorLimit',
        companyCollaboratorLimitForPlan(planId),
      );
      final active = _readInt(companyData, 'activeWorkUsers', 0);

      if (active >= limit) {
        throw StateError(
          'Limite utenti raggiunto per il piano ${_planLabel(planId)} '
          '($limit collaboratori attivi).',
        );
      }

      final next = active + 1;
      tx.set(userRef, userData);
      tx.set(
        companyRef,
        {
          'activeWorkUsers': next,
          'collaboratorLimit': limit,
        },
        SetOptions(merge: true),
      );

      for (final ref in workCodeRefs) {
        tx.set(
          ref,
          {
            'activeWorkUsers': next,
            'collaboratorLimit': limit,
            'companyId': companyId,
            'companyCode': _baseCompanyCode(companyCode),
          },
          SetOptions(merge: true),
        );
      }
    });
  }
}

final class WorkRegistrationCapacity {
  const WorkRegistrationCapacity({
    required this.allowed,
    this.message,
    this.limit,
    this.active,
  });

  final bool allowed;
  final String? message;
  final int? limit;
  final int? active;
}

final class CompanyCollaboratorUsage {
  const CompanyCollaboratorUsage({
    required this.active,
    required this.limit,
    required this.planId,
  });

  final int active;
  final int limit;
  final String planId;

  bool get atLimit => active >= limit;
}
