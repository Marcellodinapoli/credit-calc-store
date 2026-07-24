import { onCall, HttpsError } from "firebase-functions/v2/https";

import { trackAiUsage } from "./ai_usage_tracker";
import { trackNormativeSearchLog } from "./normative_search_log";
import { callOpenAiChat, ChatMessage, OPENAI_MODEL_GPT_41, openAiApiKey } from "./openai";

const region = "europe-west1";

interface HistoryItem {
  role?: string;
  content?: string;
}

function trimHistory(history: HistoryItem[] = [], maxMessages = 12): ChatMessage[] {
  const messages: ChatMessage[] = [];
  for (const item of history.slice(-maxMessages)) {
    const content = (item.content ?? "").toString().trim();
    if (!content) continue;
    const role = item.role === "assistant" ? "assistant" : "user";
    messages.push({ role, content });
  }
  return messages;
}

export const normativeSearch = onCall(
  { region, secrets: [openAiApiKey] },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError(
        "unauthenticated",
        "Accesso richiesto per la ricerca normativa.",
      );
    }

    const question = (request.data?.question ?? "").toString().trim();
    const prompt = (request.data?.prompt ?? "").toString().trim();
    const history = Array.isArray(request.data?.history)
      ? (request.data.history as HistoryItem[])
      : [];

    if (!question) {
      throw new HttpsError("invalid-argument", "Inserisci una domanda.");
    }
    if (!prompt) {
      throw new HttpsError("invalid-argument", "Prompt di sistema mancante.");
    }

    const messages: ChatMessage[] = [
      { role: "system", content: prompt },
      ...trimHistory(history),
      { role: "user", content: question },
    ];

    const result = await callOpenAiChat(messages, {
      maxTokens: 1200,
      temperature: 0.35,
      model: OPENAI_MODEL_GPT_41,
    });

    trackAiUsage({
      feature: "normativeSearch",
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

    trackNormativeSearchLog({
      userId: request.auth.uid,
      userEmail: request.auth.token.email ?? null,
      question,
      answer: result.content,
      inputTokens: result.usage.promptTokens,
      outputTokens: result.usage.completionTokens,
    });

    return { answer: result.content };
  },
);
