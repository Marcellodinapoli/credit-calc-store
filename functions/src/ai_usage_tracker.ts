import * as admin from "firebase-admin";

export type AiFeature =
  | "normativeSearch"
  | "callAnalysis"
  | "roleplayStep"
  | "roleplaySuggestion"
  | "warmupEvaluate"
  | "contestationGenerate";

export type AiUsageType = "roleplay" | "evaluation";

/** USD per 1M token (listino indicativo OpenAI). */
const MODEL_PRICING_USD: Record<string, { inputPer1M: number; outputPer1M: number }> = {
  "gpt-5.5": { inputPer1M: 1.25, outputPer1M: 10.0 },
  "gpt-4.1": { inputPer1M: 2.0, outputPer1M: 8.0 },
  "gpt-4.1-mini": { inputPer1M: 0.4, outputPer1M: 1.6 },
  "gpt-4o-realtime-preview-2024-12-17": { inputPer1M: 5.0, outputPer1M: 20.0 },
  "whisper-1": { inputPer1M: 0, outputPer1M: 0 },
};

const DEFAULT_PRICING_USD = { inputPer1M: 0.15, outputPer1M: 0.6 };
const WHISPER_USD_PER_MINUTE = 0.006;
const USD_TO_EUR = 0.92;

function currentMonthKey(): string {
  const now = new Date();
  const month = String(now.getUTCMonth() + 1).padStart(2, "0");
  return `${now.getUTCFullYear()}-${month}`;
}

export function featureToUsageType(feature: AiFeature): AiUsageType | null {
  if (feature === "roleplayStep" || feature === "roleplaySuggestion") {
    return "roleplay";
  }
  if (feature === "warmupEvaluate") {
    return "evaluation";
  }
  return null;
}

export function estimateWhisperSecondsFromBytes(byteLength: number): number {
  if (byteLength <= 0) return 0;
  return Math.max(10, Math.ceil(byteLength / 12_000));
}

export function estimateCostUsd(params: {
  model: string;
  inputTokens: number;
  outputTokens: number;
  whisperSeconds?: number;
}): number {
  const pricing = MODEL_PRICING_USD[params.model] ?? DEFAULT_PRICING_USD;
  const inputTokens = Math.max(0, params.inputTokens);
  const outputTokens = Math.max(0, params.outputTokens);
  const whisperSeconds = Math.max(0, params.whisperSeconds ?? 0);

  const chatUsd =
    (inputTokens / 1_000_000) * pricing.inputPer1M
    + (outputTokens / 1_000_000) * pricing.outputPer1M;
  const whisperUsd = (whisperSeconds / 60) * WHISPER_USD_PER_MINUTE;

  return Number((chatUsd + whisperUsd).toFixed(6));
}

function estimateCostEur(params: {
  inputTokens: number;
  outputTokens: number;
  whisperSeconds: number;
}): number {
  return estimateCostUsd({
    model: "gpt-4.1-mini",
    inputTokens: params.inputTokens,
    outputTokens: params.outputTokens,
    whisperSeconds: params.whisperSeconds,
  }) * USD_TO_EUR;
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
  responseTimeMs?: number;
  error?: string;
}): Promise<void> {
  await admin.firestore().collection("ai_usage").add({
    userId: params.userId ?? null,
    userEmail: params.userEmail ?? null,
    type: params.type,
    feature: params.feature,
    model: params.model,
    inputTokens: params.inputTokens,
    outputTokens: params.outputTokens,
    totalTokens: params.totalTokens,
    estimatedCost: params.estimatedCostUsd,
    responseTimeMs: Math.max(0, params.responseTimeMs ?? 0),
    error: params.error ?? null,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });
}

export async function recordAiUsage(params: {
  feature: AiFeature;
  inputTokens?: number;
  outputTokens?: number;
  whisperSeconds?: number;
}): Promise<void> {
  const inputTokens = Math.max(0, params.inputTokens ?? 0);
  const outputTokens = Math.max(0, params.outputTokens ?? 0);
  const whisperSeconds = Math.max(0, params.whisperSeconds ?? 0);
  const costEur = estimateCostEur({ inputTokens, outputTokens, whisperSeconds });

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
    "totals.calls": admin.firestore.FieldValue.increment(1),
    "totals.inputTokens": admin.firestore.FieldValue.increment(inputTokens),
    "totals.outputTokens": admin.firestore.FieldValue.increment(outputTokens),
    "totals.estimatedEur": admin.firestore.FieldValue.increment(costEur),
  };

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
  model?: string;
  inputTokens?: number;
  outputTokens?: number;
  totalTokens?: number;
  whisperSeconds?: number;
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
  const model = (params.model ?? "gpt-4.1-mini").trim();
  const usageType = featureToUsageType(params.feature);

  const tasks: Promise<void>[] = [
    recordAiUsage({
      feature: params.feature,
      inputTokens,
      outputTokens,
      whisperSeconds,
    }).catch((error) => {
      console.error("AI monthly usage tracking failed:", error);
    }),
  ];

  if (usageType && params.userId) {
    const estimatedCostUsd = estimateCostUsd({
      model,
      inputTokens,
      outputTokens,
      whisperSeconds,
    });

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
        responseTimeMs: params.responseTimeMs,
        error: params.error,
      }).catch((error) => {
        console.error("AI usage log write failed:", error);
      }),
    );
  }

  void Promise.all(tasks);
}
