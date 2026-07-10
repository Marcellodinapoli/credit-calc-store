import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'warmup_contestazioni_training_config_service.dart';
import 'warmup_contestazioni_training_defaults.dart';

typedef WarmupContestazioniTrainingAdminVerifier = Future<bool> Function({
  bool forceRefresh,
});

abstract final class WarmupContestazioniTrainingAdminService {
  static Map<String, dynamic> buildItemFormPayload(
    String id,
    Map<String, dynamic>? stored,
  ) {
    final defaults = WarmupContestazioniTrainingDefaults.defaultItem(id);
    final source = stored ?? defaults;
    return {
      'id': id,
      'title': (source['title'] ?? defaults['title'] ?? '').toString(),
      'subtitle': (source['subtitle'] ?? defaults['subtitle'] ?? '').toString(),
      'context': (source['context'] ?? defaults['context'] ?? 'sollecito')
          .toString(),
      'category':
          (source['category'] ?? defaults['category'] ?? 'generica').toString(),
      'order': source['order'] ?? defaults['order'] ?? 0,
      'enabled': source['enabled'] != false,
      'declared': (source['declared'] ?? defaults['declared'] ?? '').toString(),
      'meaning': (source['meaning'] ?? defaults['meaning'] ?? '').toString(),
      'risk': (source['risk'] ?? defaults['risk'] ?? '').toString(),
      'objective':
          (source['objective'] ?? defaults['objective'] ?? '').toString(),
      'response': (source['response'] ?? defaults['response'] ?? '').toString(),
      'systemPrompt':
          (source['systemPrompt'] ?? defaults['systemPrompt'] ?? '').toString(),
    };
  }

  static Map<String, dynamic> buildFirestoreItemPayload(
    Map<String, dynamic> form,
  ) {
    return WarmupContestazioneTrainingItem.fromMap(form).toFirestoreMap();
  }

  static void applyItemsConfig({
    required Map<String, dynamic>? items,
    required void Function(String id, Map<String, dynamic> payload) onItem,
  }) {
    final keys = <String>{
      ...WarmupContestazioniTrainingDefaults.allDefaultItems().keys,
      if (items != null) ...items.keys.map((k) => k.toString()),
    };
    for (final id in keys) {
      final stored = items?[id];
      final storedMap = stored is Map<String, dynamic>
          ? stored
          : stored is Map
              ? Map<String, dynamic>.from(stored)
              : null;
      onItem(id, buildItemFormPayload(id, storedMap));
    }
  }

  static Future<void> saveItems(
    Map<String, Map<String, dynamic>> items, {
    required WarmupContestazioniTrainingAdminVerifier verifyAdmin,
  }) async {
    if (!await verifyAdmin(forceRefresh: true)) {
      throw StateError('Accesso negato');
    }

    final firestoreItems = <String, dynamic>{
      for (final entry in items.entries)
        entry.key: buildFirestoreItemPayload(entry.value),
    };

    final uid = FirebaseAuth.instance.currentUser?.uid;
    await FirebaseFirestore.instance
        .collection('settings')
        .doc(WarmupContestazioniTrainingConfigService.docId)
        .set({
      'items': firestoreItems,
      'updatedAt': FieldValue.serverTimestamp(),
      if (uid != null) 'updatedBy': uid,
    }, SetOptions(merge: true));
  }
}
