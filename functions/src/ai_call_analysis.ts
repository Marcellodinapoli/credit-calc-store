import { onCall, HttpsError } from "firebase-functions/v2/https";

import { trackAiUsage } from "./ai_usage_tracker";
import { callOpenAiChat, OPENAI_MODEL_GPT_41, openAiApiKey } from "./openai";

const region = "europe-west1";

export const callAnalysis = onCall(
  { region, secrets: [openAiApiKey] },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError(
        "unauthenticated",
        "Accesso richiesto per l'analisi telefonata.",
      );
    }

    const prompt = (request.data?.prompt ?? "").toString().trim();
    const practiceText = (request.data?.practiceText ?? "").toString().trim();

    if (!prompt) {
      throw new HttpsError("invalid-argument", "Prompt di sistema mancante.");
    }
    if (!practiceText) {
      throw new HttpsError("invalid-argument", "Dati pratica mancanti.");
    }

    const result = await callOpenAiChat(
      [
        { role: "system", content: prompt },
        {
          role: "user",
          content:
            "Analizza la seguente pratica di recupero crediti e suggerisci "
            + "leve negoziali per la telefonata:\n\n"
            + practiceText,
        },
      ],
      { maxTokens: 1800, temperature: 0.4, model: OPENAI_MODEL_GPT_41 },
    );

    trackAiUsage({
      feature: "callAnalysis",
      userId: request.auth.uid,
      userEmail: request.auth.token.email,
      model: OPENAI_MODEL_GPT_41,
      inputTokens: result.usage.promptTokens,
      outputTokens: result.usage.completionTokens,
      totalTokens: result.usage.totalTokens,
      modality: result.usage.cachedTokens > 0
        ? { cachedTokens: result.usage.cachedTokens }
        : undefined,
    });

    return { analysis: result.content };
  },
);
