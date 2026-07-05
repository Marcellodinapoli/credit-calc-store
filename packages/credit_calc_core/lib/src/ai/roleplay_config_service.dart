import 'roleplay_default_simulation_prompt.dart';

/// Prompt simulazione roleplay per documento `roleplay/{id}` (campo `prompt`).
abstract final class RoleplayConfigService {
  static const collection = 'roleplay';
  static const promptField = 'prompt';
  static const legacyGptPromptField = 'gptPrompt';
  static const aiProviderField = 'aiProvider';
  static const difficultyField = 'difficulty';
  static const personalityField = 'personality';
  static const openAiProvider = 'gpt';

  static const difficulties = [
    'facile',
    'media',
    'difficile',
    'esperto',
  ];

  static const personalities = [
    'collaborativo',
    'diffidente',
    'aggressivo',
    'manipolatore',
    'emotivo',
    'razionale',
  ];

  static const defaultDifficulty = 'media';
  static const defaultPersonality = 'collaborativo';

  /// Prompt predefinito se BackOffice non ha ancora salvato nulla sulla simulazione.
  static const defaultSimulationPrompt = RoleplayDefaultSimulationPrompt.text;

  static String resolveDifficulty(Map<String, dynamic> data) {
    final raw = (data[difficultyField] ?? '').toString().trim().toLowerCase();
    return difficulties.contains(raw) ? raw : defaultDifficulty;
  }

  static String resolvePersonality(Map<String, dynamic> data) {
    final raw = (data[personalityField] ?? '').toString().trim().toLowerCase();
    return personalities.contains(raw) ? raw : defaultPersonality;
  }

  static String difficultyLabel(String value) {
    return switch (value) {
      'facile' => 'Facile',
      'difficile' => 'Difficile',
      'esperto' => 'Esperto',
      _ => 'Media',
    };
  }

  static String personalityLabel(String value) {
    return switch (value) {
      'collaborativo' => 'Collaborativo',
      'diffidente' => 'Diffidente',
      'aggressivo' => 'Aggressivo',
      'manipolatore' => 'Manipolatore',
      'emotivo' => 'Emotivo',
      'razionale' => 'Razionale',
      _ => 'Collaborativo',
    };
  }

  static String behaviorContextBlock(Map<String, dynamic> data) {
    final difficulty = resolveDifficulty(data);
    final personality = resolvePersonality(data);
    return [
      'PARAMETRI SIMULAZIONE:',
      'Difficoltà (${difficultyLabel(difficulty)}): '
          '${_difficultyHint(difficulty)}',
      'Personalità (${personalityLabel(personality)}): '
          '${_personalityHint(personality)}',
      'Rispetta sempre questi parametri nel tono e nel livello di opposizione.',
      'Hanno priorità su eventuali istruzioni di scelta casuale nel prompt.',
    ].join('\n');
  }

  static String _difficultyHint(String value) {
    return switch (value) {
      'facile' =>
        'poche obiezioni, tono generalmente disponibile al dialogo.',
      'difficile' =>
        'resistenza frequente, obiezioni solide e tono teso.',
      'esperto' =>
        'scenario complesso con obiezioni articolate, rinvii e negoziazione ostica.',
      _ => 'equilibrio tra collaborazione e opposizione, obiezioni moderate.',
    };
  }

  static String _personalityHint(String value) {
    return switch (value) {
      'collaborativo' =>
        'aperto al confronto, propone soluzioni e chiede chiarimenti.',
      'diffidente' =>
        'diffida, chiede garanzie e verifiche prima di impegnarsi.',
      'aggressivo' =>
        'tono elevato, interruzioni, minacce o rifiuti netti.',
      'manipolatore' =>
        'devia il discorso, altera i fatti o colpevolizza l\'interlocutore.',
      'emotivo' =>
        'reazioni emotive marcate (ansia, stress, frustrazione).',
      'razionale' =>
        'freddo e procedurale, chiede dettagli e contesta con logica.',
      _ => 'aperto al confronto, propone soluzioni e chiede chiarimenti.',
    };
  }

  static String resolveSimulationPrompt(Map<String, dynamic> data) {
    final prompt = (data[promptField] ?? '').toString().trim();
    if (prompt.isNotEmpty) return prompt;
    final legacyGpt =
        (data[legacyGptPromptField] ?? '').toString().trim();
    if (legacyGpt.isNotEmpty) return legacyGpt;
    return defaultSimulationPrompt;
  }

  static String resolveStoredSimulationPrompt(Map<String, dynamic> data) {
    final prompt = (data[promptField] ?? '').toString().trim();
    if (prompt.isNotEmpty) return prompt;
    return (data[legacyGptPromptField] ?? '').toString().trim();
  }
}
