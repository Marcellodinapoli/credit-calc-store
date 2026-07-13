import 'package:credit_calc_core/credit_calc_core.dart';

/// Costruisce `session.update` Realtime lato Flutter (allineato a `roleplayStep`).
abstract final class RoleplayRealtimeSessionConfig {
  static Map<String, dynamic> buildSessionUpdate({
    required Map<String, dynamic> simulationData,
    required String sessionId,
    String? responderRole,
    String? familyRelation,
  }) {
    final prompt = RoleplayConfigService.resolveSimulationPrompt(simulationData);
    final practiceData =
        simulationData['practiceData'] as List<dynamic>? ?? [];
    final scenarioWeights =
        simulationData['scenarioWeights'] as Map<String, dynamic>?;
    final role = _resolveRole(
      sessionId: sessionId,
      scenarioWeights: scenarioWeights,
      responderRole: responderRole,
    );
    final relation = _resolveFamilyRelation(
      sessionId: sessionId,
      role: role,
      familyRelation: familyRelation,
    );
    final practiceText = _buildPracticeText(practiceData);

    final roleBlock = switch (role) {
      'GARANTE' => 'Sei il GARANTE/coobbligato che risponde al telefono.',
      'TERZO' =>
        'Sei un familiare (${relation ?? 'terzo'}) che ha risposto al telefono.',
      _ => 'Sei il DEBITORE che risponde al telefono.',
    };

    final instructions = [
      prompt,
      '',
      'CONFIGURAZIONE BACKOFFICE (obbligatoria):',
      'Segui il prompt di simulazione sopra e i parametri sotto.',
      'Difficoltà, personalità e dati pratica hanno priorità su ogni istruzione '
          'di scelta casuale presente nel prompt.',
      '',
      RoleplayConfigService.behaviorContextBlock(simulationData),
      '',
      'CONTESTO LIVE ASSEGNATO DAL SISTEMA:',
      roleBlock,
      'Rispondi sempre in italiano, massimo 1-2 frasi brevi, tono telefonico '
          'realistico e umano (esitazioni, obiezioni, interruzioni naturali).',
      'Non dire mai di essere un\'intelligenza artificiale.',
      if (practiceText.isNotEmpty)
        'DATI PRATICA (usa solo questi dati, non inventare altro): $practiceText'
      else
        'DATI PRATICA: non disponibili; non inventare cifre o fatti.',
    ].join('\n');

    return {
      'type': 'session.update',
      'session': {
        'modalities': ['text', 'audio'],
        'instructions': instructions,
        'voice': role == 'TERZO' ? 'shimmer' : 'alloy',
        'input_audio_format': 'pcm16',
        'output_audio_format': 'pcm16',
        'input_audio_transcription': {'model': 'whisper-1'},
        'turn_detection': {
          'type': 'server_vad',
          'threshold': 0.5,
          'prefix_padding_ms': 300,
          'silence_duration_ms': 500,
        },
      },
    };
  }

  static String _buildPracticeText(List<dynamic> practiceData) {
    return practiceData
        .map((row) {
          if (row is! Map) return '';
          final label = (row['label'] ?? '').toString();
          final value = (row['value'] ?? '').toString();
          return '$label: $value'.trim();
        })
        .where((line) => line.isNotEmpty)
        .join('; ');
  }

  static String _resolveRole({
    required String sessionId,
    Map<String, dynamic>? scenarioWeights,
    String? responderRole,
  }) {
    final explicit = (responderRole ?? '').trim().toUpperCase();
    if (explicit.isNotEmpty) return explicit;
    return _pickRole(sessionId, scenarioWeights);
  }

  static String _pickRole(
    String sessionId,
    Map<String, dynamic>? scenarioWeights,
  ) {
    final weights = <String, double>{
      'DEBITORE': 0.4,
      'GARANTE': 0.3,
      'TERZO': 0.3,
    };
    if (scenarioWeights != null) {
      for (final role in weights.keys) {
        final value = scenarioWeights[role];
        if (value is num && value > 0) {
          weights[role] = value.toDouble();
        }
      }
    }

    var total = 0.0;
    for (final value in weights.values) {
      total += value;
    }
    if (total <= 0) return 'DEBITORE';

    var hash = 0;
    for (var i = 0; i < sessionId.length; i++) {
      hash = (hash * 31 + sessionId.codeUnitAt(i)) >>> 0;
    }
    final roll = (hash % 1000) / 1000;
    var cumulative = 0.0;
    for (final entry in weights.entries) {
      cumulative += entry.value / total;
      if (roll < cumulative) return entry.key;
    }
    return 'DEBITORE';
  }

  static String? _resolveFamilyRelation({
    required String sessionId,
    required String role,
    String? familyRelation,
  }) {
    if (role != 'TERZO') return null;
    final explicit = (familyRelation ?? '').trim();
    if (explicit.isNotEmpty) return explicit;
    const relations = ['moglie', 'figlio', 'figlia', 'fratello'];
    var hash = 0;
    for (var i = 0; i < sessionId.length; i++) {
      hash = (hash * 31 + sessionId.codeUnitAt(i)) >>> 0;
    }
    return relations[hash % relations.length];
  }
}
