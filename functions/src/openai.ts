import { defineSecret } from "firebase-functions/params";

import { HttpsError } from "firebase-functions/v2/https";

export const openAiApiKey = defineSecret("OPENAI_API_KEY");

/** Ricerca normativa, warm-up telefonata, contestazioni. */
export const OPENAI_MODEL_GPT_55 = "gpt-5.5";

/**
 * Roleplay vocale (dialogo debitore) + suggerimento scritto finale.
 * Sessione Realtime API; per i turni via Chat Completions si usa lo stesso slug.
 */
export const OPENAI_MODEL_GPT_55_REALTIME = "gpt-5.5";

/** Analisi telefonata (testo trascritto → valutazione). */
export const OPENAI_MODEL_GPT_41 = "gpt-4.1";

/** Riassunti, classificazioni, estrazione dati. */
export const OPENAI_MODEL_GPT_41_MINI = "gpt-4.1-mini";

/** Default legacy per chiamate generiche non classificate. */
export const GPT_MODEL = OPENAI_MODEL_GPT_41_MINI;

function isReasoningStyleModel(model: string): boolean {
  return model.startsWith("gpt-5") || /^o\d/.test(model);
}

export interface ChatMessage {
  role: "system" | "user" | "assistant";
  content: string;
}

export interface OpenAiUsage {
  promptTokens: number;
  completionTokens: number;
  totalTokens: number;
}

export interface OpenAiChatResult {
  content: string;
  usage: OpenAiUsage;
}

export async function callOpenAiChat(
  messages: ChatMessage[],
  options?: {
    model?: string;
    maxTokens?: number;
    temperature?: number;
    responseFormat?: { type: "json_object" };
  },
): Promise<OpenAiChatResult> {
  const apiKey = openAiApiKey.value()?.trim();
  if (!apiKey) {
    throw new HttpsError(
      "failed-precondition",
      "API OpenAI non configurata. Imposta OPENAI_API_KEY nelle Firebase Functions.",
    );
  }

  const model = options?.model ?? GPT_MODEL;
  const isReasoning = isReasoningStyleModel(model);

  const requestBody: Record<string, unknown> = {
    model,
    messages,
  };

  // API recenti: max_completion_tokens (max_tokens fallisce su gpt-5.x e modelli nuovi).
  requestBody.max_completion_tokens = options?.maxTokens ?? 1200;
  if (!isReasoning) {
    requestBody.temperature = options?.temperature ?? 0.4;
  }

  if (options?.responseFormat) {
    requestBody.response_format = options.responseFormat;
  }

  const response = await fetch("https://api.openai.com/v1/chat/completions", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${apiKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify(requestBody),
  });

  if (!response.ok) {
    const body = await response.text();
    console.error("OpenAI error:", response.status, body, "model:", model);
    throw new HttpsError(
      "internal",
      "Impossibile ottenere una risposta da OpenAI.",
    );
  }

  const payload = (await response.json()) as {
    choices?: Array<{ message?: { content?: string } }>;
    usage?: {
      prompt_tokens?: number;
      completion_tokens?: number;
      total_tokens?: number;
    };
  };
  const content = payload.choices?.[0]?.message?.content?.trim() ?? "";
  if (!content) {
    throw new HttpsError("internal", "OpenAI non ha restituito una risposta valida.");
  }

  const usage = payload.usage ?? {};
  return {
    content,
    usage: {
      promptTokens: usage.prompt_tokens ?? 0,
      completionTokens: usage.completion_tokens ?? 0,
      totalTokens: usage.total_tokens ?? 0,
    },
  };
}
