import 'package:cloud_firestore/cloud_firestore.dart';

import 'work_code_service.dart';

/// Registrazione utente collegato ad azienda tramite codice work.
abstract final class WorkCompanyLinkService {
  WorkCompanyLinkService._();

  static final _firestore = FirebaseFirestore.instance;

  static int _readInt(Map<String, dynamic>? data, String key, int fallback) {
    final raw = data?[key];
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    return fallback;
  }

  static String _baseCompanyCode(String companyCode) {
    final trimmed = companyCode.trim();
    if (trimmed.isEmpty) return trimmed;
    return trimmed.startsWith('CP-') ? trimmed : 'CP-$trimmed';
  }

  static List<String> _workCodeDocIds(String companyCode) {
    final base = _baseCompanyCode(companyCode);
    return ['$base-COL', '$base-SUP'];
  }

  static int _collaboratorLimitForPlan(String planId) {
    final normalized = switch (planId) {
      'starter' || 'plus' => 10,
      'business' => 25,
      'professional' => 50,
      'enterprise' || 'azienda' => 100,
      _ => 2,
    };
    return normalized;
  }

  static Future<WorkRegistrationCapacity> checkCapacity(String workCode) async {
    final code = workCode.trim();
    if (code.isEmpty) {
      return const WorkRegistrationCapacity(
        allowed: false,
        message: 'Codice aziendale mancante.',
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
      _collaboratorLimitForPlan(planId),
    );
    final active = _readInt(data, 'activeWorkUsers', 0);
    if (active >= limit) {
      return WorkRegistrationCapacity(
        allowed: false,
        message:
            'L\'azienda ha raggiunto il limite di $limit utenti attivi '
            'previsto dal piano. Per aggiungere collaboratori è necessario '
            'un upgrade del piano aziendale.',
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

  static Future<void> registerWorkUser({
    required WorkCompanyLinkContext link,
    required DocumentReference<Map<String, dynamic>> userRef,
    required Map<String, dynamic> userData,
  }) async {
    final companyRef = _firestore.collection('companies').doc(link.companyId);
    final codeIds = _workCodeDocIds(link.companyCode);
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
        _collaboratorLimitForPlan(planId),
      );
      final active = _readInt(companyData, 'activeWorkUsers', 0);

      if (active >= limit) {
        throw StateError(
          'Limite utenti raggiunto per il piano aziendale '
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
            'companyId': link.companyId,
            'companyCode': _baseCompanyCode(link.companyCode),
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
