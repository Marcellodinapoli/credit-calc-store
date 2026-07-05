import { onCall, HttpsError } from "firebase-functions/v2/https";

import { trackAiUsage } from "./ai_usage_tracker";
import { buildRoleplayBehaviorBlock } from "./roleplay_simulation_params";
import { callOpenAiChat, OPENAI_MODEL_GPT_55_REALTIME, openAiApiKey } from "./openai";

const region = "europe-west1";

interface HistoryItem {
  role?: string;
  content?: string;
}

function trimHistory(history: HistoryItem[] = [], maxMessages = 10): HistoryItem[] {
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
  { region, secrets: [openAiApiKey] },
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
      buildRoleplayBehaviorBlock({ difficulty, personality }),
      "",
      "CONTESTO LIVE ASSEGNATO DAL SISTEMA:",
      roleBlock,
      "Rispondi sempre in italiano, massimo 1-2 frasi brevi, tono telefonico "
      + "realistico e umano (esitazioni, obiezioni, interruzioni naturali).",
      "Non dire mai di essere un'intelligenza artificiale.",
      practiceText
        ? `DATI PRATICA (usa solo questi dati, non inventare altro): ${practiceText}`
        : "DATI PRATICA: non disponibili; non inventare cifre o fatti.",
    ]
      .filter(Boolean)
      .join("\n");

    const isOpening = trimHistory(history).length === 0 && !userText;
    if (isOpening) {
      return {
        reply: "Pronto?",
        role,
        familyRelation: role === "TERZO" ? familyRelation || "moglie" : null,
      };
    }

    const messages = [
      { role: "system" as const, content: systemPrompt },
      ...trimHistory(history).map((item) => ({
        role: item.role === "assistant" ? ("assistant" as const) : ("user" as const),
        content: item.content ?? "",
      })),
      { role: "user" as const, content: userText || "Pronto, chi parla?" },
    ];

    const result = await callOpenAiChat(messages, {
      maxTokens: 120,
      temperature: 0.75,
      model: OPENAI_MODEL_GPT_55_REALTIME,
    });

    trackAiUsage({
      feature: "roleplayStep",
      inputTokens: result.usage.promptTokens,
      outputTokens: result.usage.completionTokens,
    });

    return {
      reply: result.content,
      role,
      familyRelation: role === "TERZO" ? familyRelation || "moglie" : null,
    };
  },
);
