import 'package:cloud_firestore/cloud_firestore.dart';

import 'warmup_contestazioni_training_defaults.dart';

class WarmupContestazioneTrainingItem {
  const WarmupContestazioneTrainingItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.context,
    required this.category,
    required this.order,
    required this.enabled,
    required this.declared,
    required this.meaning,
    required this.risk,
    required this.objective,
    required this.response,
    required this.systemPrompt,
  });

  final String id;
  final String title;
  final String subtitle;
  final String context;
  final String category;
  final int order;
  final bool enabled;
  final String declared;
  final String meaning;
  final String risk;
  final String objective;
  final String response;
  final String systemPrompt;

  factory WarmupContestazioneTrainingItem.fromMap(Map<String, dynamic> raw) {
    final id = (raw['id'] ?? '').toString().trim();
    final defaults = WarmupContestazioniTrainingDefaults.defaultItem(id);
    String readString(String key) =>
        (raw[key] ?? defaults[key] ?? '').toString().trim();
    int readInt(String key) {
      final value = raw[key] ?? defaults[key];
      if (value is int) return value;
      if (value is num) return value.toInt();
      return 0;
    }

    return WarmupContestazioneTrainingItem(
      id: id,
      title: readString('title'),
      subtitle: readString('subtitle'),
      context: readString('context').isEmpty ? 'sollecito' : readString('context'),
      category: readString('category').isEmpty ? 'generica' : readString('category'),
      order: readInt('order'),
      enabled: raw['enabled'] != false,
      declared: readString('declared'),
      meaning: readString('meaning'),
      risk: readString('risk'),
      objective: readString('objective'),
      response: readString('response'),
      systemPrompt: _resolvePrompt(
        readString('systemPrompt'),
        WarmupContestazioniTrainingDefaults.defaultSystemPrompt,
      ),
    );
  }

  Map<String, dynamic> toFirestoreMap() {
    return {
      'id': id,
      'title': title,
      'subtitle': subtitle,
      'context': context,
      'category': category,
      'order': order,
      'enabled': enabled,
      'declared': declared,
      'meaning': meaning,
      'risk': risk,
      'objective': objective,
      'response': response,
      'systemPrompt': systemPrompt,
    };
  }
}

/// Config contestazioni warm-up (`settings/warmup_contestazioni_training`).
abstract final class WarmupContestazioniTrainingConfigService {
  static const docId = 'warmup_contestazioni_training';

  static String _resolvePrompt(String raw, String fallback) {
    final text = raw.trim();
    return text.isEmpty ? fallback : text;
  }

  static Map<String, WarmupContestazioneTrainingItem> resolveItems(
    Map<String, dynamic>? rawItems,
  ) {
    final out = <String, WarmupContestazioneTrainingItem>{};
    if (rawItems != null) {
      for (final entry in rawItems.entries) {
        final map = entry.value;
        if (map is! Map) continue;
        final payload = Map<String, dynamic>.from(map);
        payload['id'] = (payload['id'] ?? entry.key).toString();
        final item = WarmupContestazioneTrainingItem.fromMap(payload);
        if (item.id.isEmpty) continue;
        out[item.id] = item;
      }
    }

    for (final id in WarmupContestazioniTrainingDefaults.allDefaultItems().keys) {
      out.putIfAbsent(
        id,
        () => WarmupContestazioneTrainingItem.fromMap(
          WarmupContestazioniTrainingDefaults.defaultItem(id),
        ),
      );
    }

    return out;
  }

  static List<WarmupContestazioneTrainingItem> orderedEnabledItems(
    Map<String, WarmupContestazioneTrainingItem> items, {
    String? context,
  }) {
    final list = items.values.where((item) {
      if (!item.enabled) return false;
      if (context == null || context.isEmpty) return true;
      return item.context == context;
    }).toList()
      ..sort((a, b) {
        final order = a.order.compareTo(b.order);
        if (order != 0) return order;
        return a.title.compareTo(b.title);
      });
    return list;
  }

  static Stream<List<WarmupContestazioneTrainingItem>> watchEnabledItems({
    required String context,
  }) {
    return FirebaseFirestore.instance
        .collection('settings')
        .doc(docId)
        .snapshots()
        .map((snap) {
      final itemsRaw = snap.data()?['items'];
      final itemsMap = itemsRaw is Map<String, dynamic>
          ? itemsRaw
          : itemsRaw is Map
              ? Map<String, dynamic>.from(itemsRaw)
              : null;
      return orderedEnabledItems(resolveItems(itemsMap), context: context);
    });
  }

  static Stream<Map<String, WarmupContestazioneTrainingItem>> watchAllItems() {
    return FirebaseFirestore.instance
        .collection('settings')
        .doc(docId)
        .snapshots()
        .map((snap) {
      final itemsRaw = snap.data()?['items'];
      final itemsMap = itemsRaw is Map<String, dynamic>
          ? itemsRaw
          : itemsRaw is Map
              ? Map<String, dynamic>.from(itemsRaw)
              : null;
      return resolveItems(itemsMap);
    });
  }

  static Future<WarmupContestazioneTrainingItem?> loadItem(String id) async {
    final snap =
        await FirebaseFirestore.instance.collection('settings').doc(docId).get();
    final itemsRaw = snap.data()?['items'];
    final itemsMap = itemsRaw is Map<String, dynamic>
        ? itemsRaw
        : itemsRaw is Map
            ? Map<String, dynamic>.from(itemsRaw)
            : null;
    return resolveItems(itemsMap)[id];
  }
}
