const DIFFICULTIES = ["facile", "media", "difficile", "esperto"] as const;
const PERSONALITIES = [
  "collaborativo",
  "diffidente",
  "aggressivo",
  "manipolatore",
  "emotivo",
  "razionale",
  "realistico",
] as const;

export type RoleplayDifficulty = (typeof DIFFICULTIES)[number];
export type RoleplayPersonality = (typeof PERSONALITIES)[number];

const DEFAULT_DIFFICULTY: RoleplayDifficulty = "media";
const DEFAULT_PERSONALITY: RoleplayPersonality = "collaborativo";

function normalizeDifficulty(raw: unknown): RoleplayDifficulty {
  const value = (raw ?? "").toString().trim().toLowerCase();
  return (DIFFICULTIES as readonly string[]).includes(value)
    ? (value as RoleplayDifficulty)
    : DEFAULT_DIFFICULTY;
}

function normalizePersonality(raw: unknown): RoleplayPersonality {
  const value = (raw ?? "").toString().trim().toLowerCase();
  return (PERSONALITIES as readonly string[]).includes(value)
    ? (value as RoleplayPersonality)
    : DEFAULT_PERSONALITY;
}

function difficultyHint(value: RoleplayDifficulty): string {
  switch (value) {
    case "facile":
      return "poche obiezioni, tono generalmente disponibile al dialogo.";
    case "difficile":
      return "resistenza frequente, obiezioni solide e tono teso.";
    case "esperto":
      return "scenario complesso con obiezioni articolate, rinvii e negoziazione ostica.";
    default:
      return "equilibrio tra collaborazione e opposizione, obiezioni moderate.";
  }
}

function personalityHint(value: RoleplayPersonality): string {
  switch (value) {
    case "collaborativo":
      return "aperto al confronto, propone soluzioni e chiede chiarimenti.";
    case "diffidente":
      return "diffida, chiede garanzie e verifiche prima di impegnarsi.";
    case "aggressivo":
      return "tono elevato, interruzioni, minacce o rifiuti netti.";
    case "manipolatore":
      return "devia il discorso, altera i fatti o colpevolizza l'interlocutore.";
    case "emotivo":
      return "reazioni emotive marcate (ansia, stress, frustrazione).";
    case "razionale":
      return "freddo e procedurale, chiede dettagli e contesta con logica.";
    case "realistico":
      return (
        "misto realistico: durante la conversazione alterna e combina tratti di " +
        "aggressivo, collaborativo, diffidente, emotivo e manipolatore; " +
        "non restare su un solo stile."
      );
    default:
      return "aperto al confronto, propone soluzioni e chiede chiarimenti.";
  }
}

function difficultyLabel(value: RoleplayDifficulty): string {
  switch (value) {
    case "facile":
      return "Facile";
    case "difficile":
      return "Difficile";
    case "esperto":
      return "Esperto";
    default:
      return "Media";
  }
}

function personalityLabel(value: RoleplayPersonality): string {
  switch (value) {
    case "collaborativo":
      return "Collaborativo";
    case "diffidente":
      return "Diffidente";
    case "aggressivo":
      return "Aggressivo";
    case "manipolatore":
      return "Manipolatore";
    case "emotivo":
      return "Emotivo";
    case "razionale":
      return "Razionale";
    case "realistico":
      return "Realistico/Misto";
    default:
      return "Collaborativo";
  }
}

export function buildRoleplayBehaviorBlock(params: {
  difficulty?: unknown;
  personality?: unknown;
}): string {
  const difficulty = normalizeDifficulty(params.difficulty);
  const personality = normalizePersonality(params.personality);

  return [
    "PARAMETRI SIMULAZIONE:",
    `Difficoltà (${difficultyLabel(difficulty)}): ${difficultyHint(difficulty)}`,
    `Personalità (${personalityLabel(personality)}): ${personalityHint(personality)}`,
    "Rispetta sempre questi parametri nel tono e nel livello di opposizione.",
    "Hanno priorità su eventuali istruzioni di scelta casuale nel prompt.",
  ].join("\n");
}
