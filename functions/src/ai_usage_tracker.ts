import * as admin from "firebase-admin";

export type AiFeature =
  | "normativeSearch"
  | "callAnalysis"
  | "roleplayStep"
  | "roleplaySuggestion"
  | "roleplayRealtime"
  | "warmupEvaluate"
  | "contestationGenerate";

export type AiUsageType = "roleplay" | "evaluation" | "other";

/** Prezzi testo standard: USD per 1M token (listino OpenAI API, 2026). */
type TextPricing = {
  inputPer1M: number;
  outputPer1M: number;
  cachedInputPer1M?: number;
};

/**
 * Prezzi Realtime multimodali: USD per 1M token.
 * @see https://developers.openai.com/api/docs/pricing
 */
type RealtimePricing = {
  textInputPer1M: number;
  textCachedInputPer1M: number;
  textOutputPer1M: number;
  audioInputPer1M: number;
  audioCachedInputPer1M: number;
  audioOutputPer1M: number;
};

const TEXT_PRICING_USD: Record<string, TextPricing> = {
  "gpt-5.5": { inputPer1M: 5.0, outputPer1M: 30.0, cachedInputPer1M: 0.5 },
  "gpt-5.5-pro": { inputPer1M: 30.0, outputPer1M: 180.0 },
  "gpt-5.4": { inputPer1M: 2.5, outputPer1M: 15.0, cachedInputPer1M: 0.25 },
  "gpt-5.4-mini": {
    inputPer1M: 0.75,
    outputPer1M: 4.5,
    cachedInputPer1M: 0.075,
  },
  "gpt-5.4-nano": {
    inputPer1M: 0.2,
    outputPer1M: 1.25,
    cachedInputPer1M: 0.02,
  },
  "gpt-4.1": { inputPer1M: 2.0, outputPer1M: 8.0, cachedInputPer1M: 0.5 },
  "gpt-4.1-mini": {
    inputPer1M: 0.4,
    outputPer1M: 1.6,
    cachedInputPer1M: 0.1,
  },
  "gpt-4.1-nano": {
    inputPer1M: 0.1,
    outputPer1M: 0.4,
    cachedInputPer1M: 0.025,
  },
};

/** Alias modello sessione → listino Realtime ufficiale. */
const REALTIME_PRICING_USD: Record<string, RealtimePricing> = {
  "gpt-realtime-2.1": {
    textInputPer1M: 4.0,
    textCachedInputPer1M: 0.4,
    textOutputPer1M: 24.0,
    audioInputPer1M: 32.0,
    audioCachedInputPer1M: 0.4,
    audioOutputPer1M: 64.0,
  },
  "gpt-realtime-2.1-mini": {
    textInputPer1M: 0.6,
    textCachedInputPer1M: 0.06,
    textOutputPer1M: 2.4,
    audioInputPer1M: 10.0,
    audioCachedInputPer1M: 0.3,
    audioOutputPer1M: 20.0,
  },
  // Alias legacy / default app → tariffe gpt-realtime-2.1
  "gpt-realtime": {
    textInputPer1M: 4.0,
    textCachedInputPer1M: 0.4,
    textOutputPer1M: 24.0,
    audioInputPer1M: 32.0,
    audioCachedInputPer1M: 0.4,
    audioOutputPer1M: 64.0,
  },
};

const DEFAULT_TEXT_PRICING: TextPricing = {
  inputPer1M: 2.0,
  outputPer1M: 8.0,
  cachedInputPer1M: 0.5,
};

const WHISPER_USD_PER_MINUTE = 0.006;
const USD_TO_EUR = 0.92;

export interface AiModalityUsage {
  inputTextTokens?: number;
  inputAudioTokens?: number;
  outputTextTokens?: number;
  outputAudioTokens?: number;
  /** Totale cached input (testo+audio) se non spezzato. */
  cachedTokens?: number;
  cachedTextTokens?: number;
  cachedAudioTokens?: number;
}

function currentMonthKey(): string {
  const now = new Date();
  const month = String(now.getUTCMonth() + 1).padStart(2, "0");
  return `${now.getUTCFullYear()}-${month}`;
}

export function featureToUsageType(feature: AiFeature): AiUsageType {
  if (
    feature === "roleplayStep"
    || feature === "roleplaySuggestion"
    || feature === "roleplayRealtime"
  ) {
    return "roleplay";
  }
  if (feature === "warmupEvaluate" || feature === "contestationGenerate") {
    return "evaluation";
  }
  return "other";
}

export function estimateWhisperSecondsFromBytes(byteLength: number): number {
  if (byteLength <= 0) return 0;
  return Math.max(10, Math.ceil(byteLength / 12_000));
}

function resolveTextPricing(model: string): TextPricing {
  const key = model.trim();
  if (TEXT_PRICING_USD[key]) return TEXT_PRICING_USD[key];
  // Snapshot datati tipo gpt-5.5-2026-xx → famiglia
  for (const prefix of Object.keys(TEXT_PRICING_USD)) {
    if (key.startsWith(prefix)) return TEXT_PRICING_USD[prefix];
  }
  return DEFAULT_TEXT_PRICING;
}

function resolveRealtimePricing(model: string): RealtimePricing {
  const key = model.trim();
  if (REALTIME_PRICING_USD[key]) return REALTIME_PRICING_USD[key];
  for (const prefix of Object.keys(REALTIME_PRICING_USD)) {
    if (key.startsWith(prefix)) return REALTIME_PRICING_USD[prefix];
  }
  return REALTIME_PRICING_USD["gpt-realtime-2.1"];
}

function isRealtimeModel(model: string): boolean {
  const key = model.trim().toLowerCase();
  return key.includes("realtime") || key in REALTIME_PRICING_USD;
}

function perMillion(tokens: number, usdPer1M: number): number {
  return (Math.max(0, tokens) / 1_000_000) * usdPer1M;
}

/**
 * Costo USD dalla usage reale OpenAI + listino del modello della richiesta.
 * Per Realtime usa breakdown audio/text/cached quando disponibile.
 */
export function estimateCostUsd(params: {
  model: string;
  inputTokens: number;
  outputTokens: number;
  whisperSeconds?: number;
  modality?: AiModalityUsage;
}): number {
  const model = (params.model || "").trim() || "gpt-4.1";
  const whisperSeconds = Math.max(0, params.whisperSeconds ?? 0);
  const whisperUsd = (whisperSeconds / 60) * WHISPER_USD_PER_MINUTE;

  if (
    model === "whisper-1"
    || (
      whisperSeconds > 0
      && params.inputTokens <= 0
      && params.outputTokens <= 0
      && !params.modality
    )
  ) {
    return Number(whisperUsd.toFixed(6));
  }

  if (isRealtimeModel(model)) {
    const pricing = resolveRealtimePricing(model);
    const m = params.modality ?? {};
    const cachedText = Math.max(0, m.cachedTextTokens ?? 0);
    const cachedAudio = Math.max(0, m.cachedAudioTokens ?? 0);
    const inputText = Math.max(0, m.inputTextTokens ?? 0);
    const inputAudio = Math.max(0, m.inputAudioTokens ?? 0);
    const outputText = Math.max(0, m.outputTextTokens ?? 0);
    const outputAudio = Math.max(0, m.outputAudioTokens ?? 0);
    const hasBreakdown =
      inputText + inputAudio + outputText + outputAudio > 0;

    if (hasBreakdown) {
      const uncachedText = Math.max(0, inputText - cachedText);
      const uncachedAudio = Math.max(0, inputAudio - cachedAudio);

      const usd =
        perMillion(uncachedText, pricing.textInputPer1M)
        + perMillion(uncachedAudio, pricing.audioInputPer1M)
        + perMillion(cachedText, pricing.textCachedInputPer1M)
        + perMillion(cachedAudio, pricing.audioCachedInputPer1M)
        + perMillion(outputText, pricing.textOutputPer1M)
        + perMillion(outputAudio, pricing.audioOutputPer1M)
        + whisperUsd;

      return Number(usd.toFixed(6));
    }

    // Fallback se OpenAI non invia il breakdown: tariffa text Realtime.
    const inputTokens = Math.max(0, params.inputTokens);
    const outputTokens = Math.max(0, params.outputTokens);
    const usd =
      perMillion(inputTokens, pricing.textInputPer1M)
      + perMillion(outputTokens, pricing.textOutputPer1M)
      + whisperUsd;
    return Number(usd.toFixed(6));
  }

  const pricing = resolveTextPricing(model);
  const cached = Math.max(0, params.modality?.cachedTokens
    ?? params.modality?.cachedTextTokens
    ?? 0);
  const inputTokens = Math.max(0, params.inputTokens);
  const outputTokens = Math.max(0, params.outputTokens);
  const uncachedInput = Math.max(0, inputTokens - cached);
  const cachedRate = pricing.cachedInputPer1M ?? pricing.inputPer1M;

  const usd =
    perMillion(uncachedInput, pricing.inputPer1M)
    + perMillion(cached, cachedRate)
    + perMillion(outputTokens, pricing.outputPer1M)
    + whisperUsd;

  return Number(usd.toFixed(6));
}

export function estimateCostEur(params: {
  model: string;
  inputTokens: number;
  outputTokens: number;
  whisperSeconds?: number;
  modality?: AiModalityUsage;
}): number {
  return Number(
    (estimateCostUsd(params) * USD_TO_EUR).toFixed(6),
  );
}

/** Estrae breakdown da `response.usage` Realtime (`response.done`). */
export function modalityFromRealtimeUsage(
  usage: Record<string, unknown> | null | undefined,
): AiModalityUsage {
  if (!usage) return {};
  const inputDetails = (usage.input_token_details
    ?? usage.input_tokens_details) as Record<string, unknown> | undefined;
  const outputDetails = (usage.output_token_details
    ?? usage.output_tokens_details) as Record<string, unknown> | undefined;
  const cachedDetails = (inputDetails?.cached_tokens_details
    ?? inputDetails?.cached_token_details) as
    | Record<string, unknown>
    | undefined;

  const asInt = (v: unknown): number => {
    if (typeof v === "number" && Number.isFinite(v)) return Math.max(0, Math.floor(v));
    if (typeof v === "string") {
      const n = parseInt(v, 10);
      return Number.isFinite(n) ? Math.max(0, n) : 0;
    }
    return 0;
  };

  return {
    inputTextTokens: asInt(inputDetails?.text_tokens),
    inputAudioTokens: asInt(inputDetails?.audio_tokens),
    outputTextTokens: asInt(outputDetails?.text_tokens),
    outputAudioTokens: asInt(outputDetails?.audio_tokens),
    cachedTokens: asInt(inputDetails?.cached_tokens),
    cachedTextTokens: asInt(cachedDetails?.text_tokens),
    cachedAudioTokens: asInt(cachedDetails?.audio_tokens),
  };
}

async function writeUsageLog(params: {
  userId?: string;
  userEmail?: string;
  type: AiUsageType;
  feature: AiFeature;
  model: string;
  inputTokens: number;
  outputTokens: number;
  totalTokens: number;
  estimatedCostUsd: number;
  modality?: AiModalityUsage;
  whisperSeconds?: number;
  responseTimeMs?: number;
  error?: string;
}): Promise<void> {
  const modality = params.modality ?? {};
  await admin.firestore().collection("ai_usage").add({
    userId: params.userId ?? null,
    userEmail: params.userEmail ?? null,
    type: params.type,
    feature: params.feature,
    model: params.model,
    inputTokens: params.inputTokens,
    outputTokens: params.outputTokens,
    totalTokens: params.totalTokens,
    inputTextTokens: modality.inputTextTokens ?? 0,
    inputAudioTokens: modality.inputAudioTokens ?? 0,
    outputTextTokens: modality.outputTextTokens ?? 0,
    outputAudioTokens: modality.outputAudioTokens ?? 0,
    cachedTokens: modality.cachedTokens ?? 0,
    cachedTextTokens: modality.cachedTextTokens ?? 0,
    cachedAudioTokens: modality.cachedAudioTokens ?? 0,
    whisperSeconds: Math.max(0, params.whisperSeconds ?? 0),
    estimatedCost: params.estimatedCostUsd,
    estimatedCostUsd: params.estimatedCostUsd,
    responseTimeMs: Math.max(0, params.responseTimeMs ?? 0),
    error: params.error ?? null,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });
}

export async function recordAiUsage(params: {
  feature: AiFeature;
  model: string;
  inputTokens?: number;
  outputTokens?: number;
  whisperSeconds?: number;
  modality?: AiModalityUsage;
}): Promise<void> {
  const inputTokens = Math.max(0, params.inputTokens ?? 0);
  const outputTokens = Math.max(0, params.outputTokens ?? 0);
  const whisperSeconds = Math.max(0, params.whisperSeconds ?? 0);
  const modality = params.modality ?? {};
  const costEur = estimateCostEur({
    model: params.model,
    inputTokens,
    outputTokens,
    whisperSeconds,
    modality,
  });

  const ref = admin
    .firestore()
    .collection("settings")
    .doc("ai_usage")
    .collection("months")
    .doc(currentMonthKey());

  const update: Record<string, admin.firestore.FieldValue | admin.firestore.Timestamp> = {
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    [`features.${params.feature}.calls`]: admin.firestore.FieldValue.increment(1),
    [`features.${params.feature}.inputTokens`]:
      admin.firestore.FieldValue.increment(inputTokens),
    [`features.${params.feature}.outputTokens`]:
      admin.firestore.FieldValue.increment(outputTokens),
    [`features.${params.feature}.estimatedEur`]:
      admin.firestore.FieldValue.increment(costEur),
    "totals.calls": admin.firestore.FieldValue.increment(1),
    "totals.inputTokens": admin.firestore.FieldValue.increment(inputTokens),
    "totals.outputTokens": admin.firestore.FieldValue.increment(outputTokens),
    "totals.estimatedEur": admin.firestore.FieldValue.increment(costEur),
  };

  const inputAudio = modality.inputAudioTokens ?? 0;
  const outputAudio = modality.outputAudioTokens ?? 0;
  const cached = modality.cachedTokens ?? 0;
  if (inputAudio > 0) {
    update["totals.inputAudioTokens"] =
      admin.firestore.FieldValue.increment(inputAudio);
    update[`features.${params.feature}.inputAudioTokens`] =
      admin.firestore.FieldValue.increment(inputAudio);
  }
  if (outputAudio > 0) {
    update["totals.outputAudioTokens"] =
      admin.firestore.FieldValue.increment(outputAudio);
    update[`features.${params.feature}.outputAudioTokens`] =
      admin.firestore.FieldValue.increment(outputAudio);
  }
  if (cached > 0) {
    update["totals.cachedTokens"] =
      admin.firestore.FieldValue.increment(cached);
    update[`features.${params.feature}.cachedTokens`] =
      admin.firestore.FieldValue.increment(cached);
  }

  if (whisperSeconds > 0) {
    update[`features.${params.feature}.whisperSeconds`] =
      admin.firestore.FieldValue.increment(whisperSeconds);
    update["totals.whisperSeconds"] =
      admin.firestore.FieldValue.increment(whisperSeconds);
  }

  await ref.set(update, { merge: true });
}

export function trackAiUsage(params: {
  feature: AiFeature;
  userId?: string;
  userEmail?: string;
  /** Modello reale della richiesta — obbligatorio per costi corretti. */
  model: string;
  inputTokens?: number;
  outputTokens?: number;
  totalTokens?: number;
  whisperSeconds?: number;
  modality?: AiModalityUsage;
  responseTimeMs?: number;
  error?: string;
}): void {
  const inputTokens = Math.max(0, params.inputTokens ?? 0);
  const outputTokens = Math.max(0, params.outputTokens ?? 0);
  const totalTokens = Math.max(
    0,
    params.totalTokens ?? inputTokens + outputTokens,
  );
  const whisperSeconds = Math.max(0, params.whisperSeconds ?? 0);
  const model = (params.model ?? "").trim() || "gpt-4.1";
  const modality = params.modality;
  const usageType = featureToUsageType(params.feature);
  const estimatedCostUsd = estimateCostUsd({
    model,
    inputTokens,
    outputTokens,
    whisperSeconds,
    modality,
  });

  const tasks: Promise<void>[] = [
    recordAiUsage({
      feature: params.feature,
      model,
      inputTokens,
      outputTokens,
      whisperSeconds,
      modality,
    }).catch((error) => {
      console.error("AI monthly usage tracking failed:", error);
    }),
  ];

  // Log evento per tutte le feature (niente eccezioni di copertura).
  tasks.push(
    writeUsageLog({
      userId: params.userId,
      userEmail: params.userEmail,
      type: usageType,
      feature: params.feature,
      model,
      inputTokens,
      outputTokens,
      totalTokens,
      estimatedCostUsd,
      modality,
      whisperSeconds,
      responseTimeMs: params.responseTimeMs,
      error: params.error,
    }).catch((error) => {
      console.error("AI usage log write failed:", error);
    }),
  );

  void Promise.all(tasks);
}
