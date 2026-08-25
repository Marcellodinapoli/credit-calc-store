import { onCall, HttpsError } from "firebase-functions/v2/https";

import { trackAiUsage } from "./ai_usage_tracker";
import { buildRoleplayBehaviorBlock } from "./roleplay_simulation_params";
import { callOpenAiChat, OPENAI_MODEL_GPT_55_REALTIME, openAiApiKey } from "./openai";

const region = "europe-west1";

interface HistoryItem {
  role?: string;
  content?: string;
}

function trimHistory(history: HistoryItem[] = [], maxMessages = 6): HistoryItem[] {
  return history
    .slice(-maxMessages)
    .map((item) => ({
      role: item.role === "assistant" ? "assistant" : "user",
      content: (item.content ?? "").toString().trim(),
    }))
    .filter((item) => item.content.length > 0);
}

function buildPracticeText(practiceData: unknown): string {
  if (!Array.isArray(practiceData)) return "";
  return practiceData
    .map((row) => {
      if (!row || typeof row !== "object") return "";
      const label = (row as { label?: string }).label ?? "";
      const value = (row as { value?: string }).value ?? "";
      return `${label}: ${value}`.trim();
    })
    .filter(Boolean)
    .join("; ");
}

function pickRole(sessionId: string, scenarioWeights?: Record<string, number>): string {
  const weights = scenarioWeights ?? { DEBITORE: 0.4, GARANTE: 0.3, TERZO: 0.3 };
  let total = 0;
  for (const value of Object.values(weights)) {
    if (typeof value === "number" && value > 0) total += value;
  }
  if (!total) return "DEBITORE";

  let hash = 0;
  for (let i = 0; i < sessionId.length; i += 1) {
    hash = (hash * 31 + sessionId.charCodeAt(i)) >>> 0;
  }
  const roll = (hash % 1000) / 1000;
  let cumulative = 0;
  for (const [role, weight] of Object.entries(weights)) {
    cumulative += weight / total;
    if (roll < cumulative) return role;
  }
  return "DEBITORE";
}

export const roleplayStep = onCall(
  // invoker public: Gen2/Cloud Run raggiungibile da qualsiasi PC/cell
  // con Firebase Auth (il check auth resta sotto).
  { region, secrets: [openAiApiKey], invoker: "public" },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError(
        "unauthenticated",
        "Accesso richiesto per la simulazione roleplay.",
      );
    }

    const userText = (request.data?.userText ?? "").toString().trim();
    const prompt = (request.data?.prompt ?? "").toString().trim();
    const sessionId = (request.data?.sessionId ?? "default").toString();
    const history = Array.isArray(request.data?.history)
      ? (request.data.history as HistoryItem[])
      : [];
    const practiceData = request.data?.practiceData;
    const scenarioWeights = request.data?.scenarioWeights as
      | Record<string, number>
      | undefined;
    const responderRole = (request.data?.responderRole ?? "").toString().trim();
    const familyRelation = (request.data?.familyRelation ?? "").toString().trim();
    const difficulty = request.data?.difficulty;
    const personality = request.data?.personality;

    if (!prompt) {
      throw new HttpsError("invalid-argument", "Prompt simulazione mancante.");
    }

    const role = responderRole.toUpperCase() || pickRole(sessionId, scenarioWeights);
    const practiceText = buildPracticeText(practiceData);

    const roleBlock =
      role === "GARANTE"
        ? "Sei il GARANTE/coobbligato che risponde al telefono."
        : role === "TERZO"
          ? `Sei un familiare (${familyRelation || "terzo"}) che ha risposto al telefono.`
          : "Sei il DEBITORE che risponde al telefono.";

    const systemPrompt = [
      prompt,
      "",
      "CONFIGURAZIONE BACKOFFICE (obbligatoria):",
      "Segui il prompt di simulazione sopra e i parametri sotto.",
      "Difficoltà, personalità e dati pratica hanno priorità su ogni istruzione "
      + "di scelta casuale presente nel prompt.",
      "",
      buildRoleplayBehaviorBlock({ difficulty, personality }),
      "",
      "CONTESTO LIVE ASSEGNATO DAL SISTEMA:",
      roleBlock,
      "Rispondi normalmente come in una telefonata reale. Ogni turno deve "
      + "essere generalmente composto da 1-2 frasi complete e concise. "
      + "Concludi sempre il pensiero prima di terminare la risposta. "
      + "Solo se la situazione lo richiede puoi utilizzare una frase "
      + "leggermente più lunga.",
      "Rispondi sempre in italiano, tono telefonico realistico e umano.",
      "Non dire mai di essere un'intelligenza artificiale.",
      practiceText
        ? `DATI PRATICA (usa solo questi dati, non inventare altro): ${practiceText}`
        : "DATI PRATICA: non disponibili; non inventare cifre o fatti.",
    ]
      .filter(Boolean)
      .join("\n");

    const isOpening = trimHistory(history).length === 0 && !userText;

    // Apertura chiamata: usa sempre il prompt BK + OpenAI (niente "Pronto?" hardcoded).
    const openingCue =
      "[SISTEMA: la telefonata è appena iniziata. Alza il telefono e fai " +
      "la prima battuta come farebbe il personaggio assegnato dal prompt e " +
      "dai parametri sopra. Una sola frase breve, tono telefonico realistico. " +
      "Non presentarti come AI.]";

    const messages = [
      { role: "system" as const, content: systemPrompt },
      ...trimHistory(history).map((item) => ({
        role: item.role === "assistant" ? ("assistant" as const) : ("user" as const),
        content: item.content ?? "",
      })),
      {
        role: "user" as const,
        content: userText || (isOpening ? openingCue : "Pronto, chi parla?"),
      },
    ];

    const startedAt = Date.now();
    try {
    const result = await callOpenAiChat(messages, {
      maxTokens: 60,
      model: OPENAI_MODEL_GPT_55_REALTIME,
      reasoningEffort: "none",
    });

    trackAiUsage({
      feature: "roleplayStep",
      userId: request.auth.uid,
      userEmail: request.auth.token.email,
      model: OPENAI_MODEL_GPT_55_REALTIME,
      inputTokens: result.usage.promptTokens,
      outputTokens: result.usage.completionTokens,
      totalTokens: result.usage.totalTokens,
      modality: result.usage.cachedTokens > 0
        ? { cachedTokens: result.usage.cachedTokens }
        : undefined,
      responseTimeMs: Date.now() - startedAt,
    });

    return {
      reply: result.content,
      role,
      familyRelation: role === "TERZO" ? familyRelation || "moglie" : null,
    };
    } catch (error) {
      trackAiUsage({
        feature: "roleplayStep",
        userId: request.auth.uid,
        userEmail: request.auth.token.email,
        model: OPENAI_MODEL_GPT_55_REALTIME,
        responseTimeMs: Date.now() - startedAt,
        error: error instanceof Error ? error.message : "roleplayStep failed",
      });
      throw error;
    }
  },
);
