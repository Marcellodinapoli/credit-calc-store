import * as admin from "firebase-admin";

export type AiFeature =
  | "normativeSearch"
  | "callAnalysis"
  | "roleplayStep"
  | "warmupEvaluate";

/** Tariffe indicative miste (USD → EUR, stima). */
const CHAT_INPUT_USD_PER_1M = 0.15;
const CHAT_OUTPUT_USD_PER_1M = 0.6;
const WHISPER_USD_PER_MINUTE = 0.006;
const USD_TO_EUR = 0.92;

function currentMonthKey(): string {
  const now = new Date();
  const month = String(now.getUTCMonth() + 1).padStart(2, "0");
  return `${now.getUTCFullYear()}-${month}`;
}

function estimateCostEur(params: {
  inputTokens: number;
  outputTokens: number;
  whisperSeconds: number;
}): number {
  const usd =
    (params.inputTokens / 1_000_000) * CHAT_INPUT_USD_PER_1M
    + (params.outputTokens / 1_000_000) * CHAT_OUTPUT_USD_PER_1M
    + (params.whisperSeconds / 60) * WHISPER_USD_PER_MINUTE;
  return usd * USD_TO_EUR;
}

export function estimateWhisperSecondsFromBytes(byteLength: number): number {
  if (byteLength <= 0) return 0;
  return Math.max(10, Math.ceil(byteLength / 12_000));
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
  inputTokens?: number;
  outputTokens?: number;
  whisperSeconds?: number;
}): void {
  recordAiUsage(params).catch((error) => {
    console.error("AI usage tracking failed:", error);
  });
}
