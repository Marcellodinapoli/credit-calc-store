import { onCall, HttpsError } from "firebase-functions/v2/https";

import { trackAiUsage } from "./ai_usage_tracker";
import {
  callOpenAiChat,
  ChatMessage,
  OPENAI_MODEL_GPT_55_REALTIME,
  openAiApiKey,
} from "./openai";

const region = "europe-west1";

interface HistoryItem {
  role?: string;
  content?: string;
}

function trimHistory(history: HistoryItem[] = [], maxMessages = 24): ChatMessage[] {
  return history
    .slice(-maxMessages)
    .map((item) => ({
      role: item.role === "assistant" ? "assistant" as const : "user" as const,
      content: (item.content ?? "").toString().trim(),
    }))
    .filter((item) => item.content.length > 0);
}

export const roleplaySuggestion = onCall(
  { region, secrets: [openAiApiKey] },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError(
        "unauthenticated",
        "Accesso richiesto per il suggerimento roleplay.",
      );
    }

    const prompt = (request.data?.prompt ?? "").toString().trim();
    const practiceText = (request.data?.practiceText ?? "").toString().trim();
    const title = (request.data?.title ?? "Simulazione").toString().trim();
    const history = Array.isArray(request.data?.history)
      ? (request.data.history as HistoryItem[])
      : [];

    if (!prompt) {
      throw new HttpsError("invalid-argument", "Prompt simulazione mancante.");
    }

    const transcript = trimHistory(history);
    if (transcript.length === 0) {
      throw new HttpsError(
        "invalid-argument",
        "Completa almeno uno scambio prima di chiedere il suggerimento.",
      );
    }

    const systemPrompt = [
      prompt,
      "",
      "FASE VALUTAZIONE FINALE (dopo la telefonata simulata):",
      "Esci dal personaggio. Sei un coach per consulenti del recupero crediti.",
      "Analizza la trascrizione e fornisci in italiano, con queste sezioni:",
      "1. Punteggio (0-100)",
      "2. Errori (errori principali commessi dal consulente)",
      "3. Privacy (eventuali violazioni della privacy)",
      "4. Tecnica negoziale (ascolto, identificazione interlocutore, gestione contestazioni, persuasione, leve, chiusura)",
      "5. Come migliorare (massimo 5 suggerimenti pratici)",
      practiceText ? `DATI PRATICA: ${practiceText}` : "",
    ]
      .filter(Boolean)
      .join("\n");

    const messages: ChatMessage[] = [
      { role: "system", content: systemPrompt },
      {
        role: "user",
        content:
          `Simulazione: ${title}\n\n`
          + "Trascrizione della telefonata simulata:\n"
          + transcript
            .map((m) => `${m.role === "assistant" ? "Debitore" : "Consulente"}: ${m.content}`)
            .join("\n"),
      },
    ];

    const result = await callOpenAiChat(messages, {
      maxTokens: 1400,
      temperature: 0.45,
      model: OPENAI_MODEL_GPT_55_REALTIME,
    });

    trackAiUsage({
      feature: "roleplayStep",
      inputTokens: result.usage.promptTokens,
      outputTokens: result.usage.completionTokens,
    });

    return { suggestion: result.content };
  },
);
