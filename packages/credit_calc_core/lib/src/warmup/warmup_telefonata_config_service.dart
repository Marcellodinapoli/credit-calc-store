import 'package:cloud_firestore/cloud_firestore.dart';

import 'warmup_telefonata_defaults.dart';

String _resolveWarmupPrompt(String raw, String fallback) {
  final text = raw.trim();
  return text.isEmpty ? fallback : text;
}

class WarmupTelefonataPhase {
  const WarmupTelefonataPhase({
    required this.phaseKey,
    required this.sectionTitle,
    required this.group,
    required this.order,
    required this.enabled,
    required this.colorValue,
    required this.customerLine,
    required this.decodifica,
    required this.spiegazione,
    required this.evaluationCriteria,
    required this.systemPrompt,
    required this.phaseInstruction,
    this.targetPersonName,
    this.callingOnBehalfOf,
    this.responseGuidance,
  });

  final String phaseKey;
  final String sectionTitle;
  final String group;
  final int order;
  final bool enabled;
  final int colorValue;
  final String customerLine;
  final String decodifica;
  final String spiegazione;
  final String evaluationCriteria;
  final String systemPrompt;
  final String phaseInstruction;
  final String? targetPersonName;
  final String? callingOnBehalfOf;
  final String? responseGuidance;

  factory WarmupTelefonataPhase.fromMap(Map<String, dynamic> raw) {
    final phaseKey = (raw['phaseKey'] ?? '').toString().trim();
    final defaults = WarmupTelefonataDefaults.defaultPhase(phaseKey);
    String readString(String key) =>
        (raw[key] ?? defaults[key] ?? '').toString().trim();
    int readInt(String key) {
      final value = raw[key] ?? defaults[key];
      if (value is int) return value;
      if (value is num) return value.toInt();
      return 0;
    }

    final target = readString('targetPersonName');
    final behalf = readString('callingOnBehalfOf');
    final guidance = readString('responseGuidance');

    return WarmupTelefonataPhase(
      phaseKey: phaseKey,
      sectionTitle: readString('sectionTitle'),
      group: readString('group'),
      order: readInt('order'),
      enabled: raw['enabled'] != false,
      colorValue: readInt('colorValue'),
      customerLine: readString('customerLine'),
      decodifica: readString('decodifica'),
      spiegazione: readString('spiegazione'),
      evaluationCriteria: readString('evaluationCriteria'),
      systemPrompt: _resolveWarmupPrompt(
        readString('systemPrompt'),
        WarmupTelefonataDefaults.defaultSystemPrompt,
      ),
      phaseInstruction: readString('phaseInstruction'),
      targetPersonName: target.isEmpty ? null : target,
      callingOnBehalfOf: behalf.isEmpty ? null : behalf,
      responseGuidance: guidance.isEmpty ? null : guidance,
    );
  }

  Map<String, dynamic> toFirestoreMap() {
    return {
      'phaseKey': phaseKey,
      'sectionTitle': sectionTitle,
      'group': group,
      'order': order,
      'enabled': enabled,
      'colorValue': colorValue,
      'customerLine': customerLine,
      'decodifica': decodifica,
      'spiegazione': spiegazione,
      'evaluationCriteria': evaluationCriteria,
      'systemPrompt': systemPrompt,
      'phaseInstruction': phaseInstruction,
      if (targetPersonName != null) 'targetPersonName': targetPersonName,
      if (callingOnBehalfOf != null) 'callingOnBehalfOf': callingOnBehalfOf,
      if (responseGuidance != null) 'responseGuidance': responseGuidance,
    };
  }
}

/// Config warm-up telefonata (`settings/warmup_telefonata`).
abstract final class WarmupTelefonataConfigService {
  static const docId = 'warmup_telefonata';

  static Map<String, WarmupTelefonataPhase> resolvePhases(
    Map<String, dynamic>? rawPhases,
  ) {
    final out = <String, WarmupTelefonataPhase>{};
    if (rawPhases != null) {
      for (final entry in rawPhases.entries) {
        final map = entry.value;
        if (map is! Map) continue;
        final payload = Map<String, dynamic>.from(map);
        payload['phaseKey'] = (payload['phaseKey'] ?? entry.key).toString();
        final phase = WarmupTelefonataPhase.fromMap(payload);
        if (phase.phaseKey.isEmpty) continue;
        out[phase.phaseKey] = phase;
      }
    }

    for (final key in WarmupTelefonataDefaults.phaseKeys) {
      out.putIfAbsent(
        key,
        () => WarmupTelefonataPhase.fromMap(
          WarmupTelefonataDefaults.defaultPhase(key),
        ),
      );
    }

    return out;
  }

  static List<WarmupTelefonataPhase> orderedEnabledPhases(
    Map<String, WarmupTelefonataPhase> phases,
  ) {
    final list = phases.values.where((p) => p.enabled).toList()
      ..sort((a, b) {
        final order = a.order.compareTo(b.order);
        if (order != 0) return order;
        return a.sectionTitle.compareTo(b.sectionTitle);
      });
    return list;
  }

  static Stream<List<WarmupTelefonataPhase>> watchEnabledPhases() {
    return FirebaseFirestore.instance
        .collection('settings')
        .doc(docId)
        .snapshots()
        .map((snap) {
      final phasesRaw = snap.data()?['phases'];
      final phasesMap = phasesRaw is Map<String, dynamic>
          ? phasesRaw
          : phasesRaw is Map
              ? Map<String, dynamic>.from(phasesRaw)
              : null;
      return orderedEnabledPhases(resolvePhases(phasesMap));
    });
  }

  static Stream<Map<String, WarmupTelefonataPhase>> watchAllPhases() {
    return FirebaseFirestore.instance
        .collection('settings')
        .doc(docId)
        .snapshots()
        .map((snap) {
      final phasesRaw = snap.data()?['phases'];
      final phasesMap = phasesRaw is Map<String, dynamic>
          ? phasesRaw
          : phasesRaw is Map
              ? Map<String, dynamic>.from(phasesRaw)
              : null;
      return resolvePhases(phasesMap);
    });
  }

  static Future<WarmupTelefonataPhase> loadPhase(String phaseKey) async {
    final snap =
        await FirebaseFirestore.instance.collection('settings').doc(docId).get();
    final phasesRaw = snap.data()?['phases'];
    final phasesMap = phasesRaw is Map<String, dynamic>
        ? phasesRaw
        : phasesRaw is Map
            ? Map<String, dynamic>.from(phasesRaw)
            : null;
    final phases = resolvePhases(phasesMap);
    return phases[phaseKey] ??
        WarmupTelefonataPhase.fromMap(
          WarmupTelefonataDefaults.defaultPhase(phaseKey),
        );
  }
}
