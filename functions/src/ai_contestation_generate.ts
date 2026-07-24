import { onCall, HttpsError } from "firebase-functions/v2/https";

import { trackAiUsage } from "./ai_usage_tracker";
import {
  callOpenAiChat,
  OPENAI_MODEL_GPT_55,
  openAiApiKey,
} from "./openai";

const region = "europe-west1";

const VALID_CATEGORIES = new Set([
  "economica",
  "legale",
  "salute",
  "amministrativa",
  "generica",
]);

function normalizeCategory(raw: unknown): string {
  const value = (raw ?? "").toString().trim().toLowerCase();
  return VALID_CATEGORIES.has(value) ? value : "generica";
}

export const contestationGenerate = onCall(
  { region, secrets: [openAiApiKey] },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError(
        "unauthenticated",
        "Accesso richiesto per generare le schede di analisi.",
      );
    }

    const declared = (request.data?.declared ?? "").toString().trim();
    const context = (request.data?.context ?? "sollecito").toString().trim();

    if (!declared) {
      throw new HttpsError(
        "invalid-argument",
        "Contestazione dichiarata mancante.",
      );
    }

    const contextLabel = context === "recupero"
      ? "recupero crediti"
      : "sollecito di pagamento";

    const systemPrompt = [
      "Sei un formatore esperto in recupero crediti e gestione contestazioni telefoniche.",
      `Analizza la contestazione che il debitore dichiara al telefono nel contesto di ${contextLabel}.`,
      "Restituisci SOLO un JSON valido con queste chiavi:",
      '- "meaning": cosa sta comunicando davvero (2-3 frasi, italiano)',
      '- "risk": rischio se gestita male dall\'operatore (1-2 frasi)',
      '- "objective": obiettivo dell\'operatore di recupero crediti (1-2 frasi)',
      '- "response": linea di risposta corretta dell\'operatore, tra virgolette italiane «...»',
      '- "category": una tra "economica", "legale", "salute", "amministrativa", "generica"',
      "",
      "Stile: professionale, concreto, adatto a formazione operatori call center recupero crediti.",
    ].join("\n");

    const chat = await callOpenAiChat(
      [
        { role: "system", content: systemPrompt },
        {
          role: "user",
          content: `Contestazione dichiarata dal cliente:\n«${declared}»`,
        },
      ],
      {
        model: OPENAI_MODEL_GPT_55,
        maxTokens: 1200,
        responseFormat: { type: "json_object" },
      },
    );

    trackAiUsage({
      feature: "contestationGenerate",
      userId: request.auth.uid,
      userEmail: request.auth.token.email,
      model: OPENAI_MODEL_GPT_55,
      inputTokens: chat.usage.promptTokens,
      outputTokens: chat.usage.completionTokens,
      totalTokens: chat.usage.totalTokens,
      modality: chat.usage.cachedTokens > 0
        ? { cachedTokens: chat.usage.cachedTokens }
        : undefined,
    });

    let parsed: Record<string, unknown>;
    try {
      parsed = JSON.parse(chat.content) as Record<string, unknown>;
    } catch {
      throw new HttpsError("internal", "Risposta AI non valida.");
    }

    const meaning = (parsed.meaning ?? "").toString().trim();
    const risk = (parsed.risk ?? "").toString().trim();
    const objective = (parsed.objective ?? "").toString().trim();
    const response = (parsed.response ?? "").toString().trim();

    if (!meaning || !risk || !objective || !response) {
      throw new HttpsError(
        "internal",
        "L'AI non ha compilato tutte le schede di analisi.",
      );
    }

    return {
      meaning,
      risk,
      objective,
      response,
      category: normalizeCategory(parsed.category),
    };
  },
);
