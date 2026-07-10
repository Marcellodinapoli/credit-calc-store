import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'warmup_telefonata_config_service.dart';
import 'warmup_telefonata_defaults.dart';

typedef WarmupTelefonataAdminVerifier = Future<bool> Function({
  bool forceRefresh,
});

abstract final class WarmupTelefonataAdminService {
  static Map<String, dynamic> buildPhaseFormPayload(
    String phaseKey,
    Map<String, dynamic>? stored,
  ) {
    final defaults = WarmupTelefonataDefaults.defaultPhase(phaseKey);
    final source = stored ?? defaults;
    return {
      'phaseKey': phaseKey,
      'sectionTitle': (source['sectionTitle'] ?? defaults['sectionTitle'] ?? '')
          .toString(),
      'group': (source['group'] ?? defaults['group'] ?? '').toString(),
      'order': source['order'] ?? defaults['order'] ?? 0,
      'enabled': source['enabled'] != false,
      'colorValue': source['colorValue'] ?? defaults['colorValue'] ?? 0xFF1E88E5,
      'customerLine': (source['customerLine'] ?? defaults['customerLine'] ?? '')
          .toString(),
      'targetPersonName':
          (source['targetPersonName'] ?? defaults['targetPersonName'] ?? '')
              .toString(),
      'callingOnBehalfOf':
          (source['callingOnBehalfOf'] ?? defaults['callingOnBehalfOf'] ?? '')
              .toString(),
      'responseGuidance':
          (source['responseGuidance'] ?? defaults['responseGuidance'] ?? '')
              .toString(),
      'decodifica': (source['decodifica'] ?? defaults['decodifica'] ?? '')
          .toString(),
      'spiegazione': (source['spiegazione'] ?? defaults['spiegazione'] ?? '')
          .toString(),
      'evaluationCriteria':
          (source['evaluationCriteria'] ?? defaults['evaluationCriteria'] ?? '')
              .toString(),
      'systemPrompt':
          (source['systemPrompt'] ?? defaults['systemPrompt'] ?? '').toString(),
      'phaseInstruction':
          (source['phaseInstruction'] ?? defaults['phaseInstruction'] ?? '')
              .toString(),
    };
  }

  static Map<String, dynamic> buildFirestorePhasePayload(
    Map<String, dynamic> form,
  ) {
    return WarmupTelefonataPhase.fromMap(form).toFirestoreMap();
  }

  static void applyPhasesConfig({
    required Map<String, dynamic>? phases,
    required void Function(String phaseKey, Map<String, dynamic> payload) onPhase,
  }) {
    final keys = <String>{
      ...WarmupTelefonataDefaults.phaseKeys,
      if (phases != null) ...phases.keys.map((k) => k.toString()),
    };
    for (final key in keys) {
      final stored = phases?[key];
      final storedMap = stored is Map<String, dynamic>
          ? stored
          : stored is Map
              ? Map<String, dynamic>.from(stored)
              : null;
      onPhase(key, buildPhaseFormPayload(key, storedMap));
    }
  }

  static Future<void> savePhases(
    Map<String, Map<String, dynamic>> phases, {
    required WarmupTelefonataAdminVerifier verifyAdmin,
  }) async {
    if (!await verifyAdmin(forceRefresh: true)) {
      throw StateError('Accesso negato');
    }

    final firestorePhases = <String, dynamic>{
      for (final entry in phases.entries)
        entry.key: buildFirestorePhasePayload(entry.value),
    };

    final uid = FirebaseAuth.instance.currentUser?.uid;
    await FirebaseFirestore.instance
        .collection('settings')
        .doc(WarmupTelefonataConfigService.docId)
        .set({
      'phases': firestorePhases,
      'updatedAt': FieldValue.serverTimestamp(),
      if (uid != null) 'updatedBy': uid,
    }, SetOptions(merge: true));
  }
}
