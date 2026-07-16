import * as admin from "firebase-admin";
import { onCall, HttpsError } from "firebase-functions/v2/https";

const region = "europe-west1";

interface UsageTotals {
  calls: number;
  inputTokens: number;
  outputTokens: number;
  totalTokens: number;
  estimatedCostUsd: number;
  errors: number;
}

interface UsageRow {
  key: string;
  label: string;
  calls: number;
  inputTokens: number;
  outputTokens: number;
  totalTokens: number;
  estimatedCostUsd: number;
  errors: number;
}

function emptyTotals(): UsageTotals {
  return {
    calls: 0,
    inputTokens: 0,
    outputTokens: 0,
    totalTokens: 0,
    estimatedCostUsd: 0,
    errors: 0,
  };
}

function addToTotals(target: UsageTotals, doc: Record<string, unknown>): void {
  target.calls += 1;
  target.inputTokens += Number(doc.inputTokens ?? 0);
  target.outputTokens += Number(doc.outputTokens ?? 0);
  target.totalTokens += Number(doc.totalTokens ?? 0);
  target.estimatedCostUsd += Number(doc.estimatedCost ?? 0);
  if (doc.error) target.errors += 1;
}

function dayKeyFromTimestamp(value: admin.firestore.Timestamp): string {
  const date = value.toDate();
  const y = date.getUTCFullYear();
  const m = String(date.getUTCMonth() + 1).padStart(2, "0");
  const d = String(date.getUTCDate()).padStart(2, "0");
  return `${y}-${m}-${d}`;
}

function mapRow(key: string, label: string, totals: UsageTotals): UsageRow {
  return {
    key,
    label,
    calls: totals.calls,
    inputTokens: totals.inputTokens,
    outputTokens: totals.outputTokens,
    totalTokens: totals.totalTokens,
    estimatedCostUsd: Number(totals.estimatedCostUsd.toFixed(4)),
    errors: totals.errors,
  };
}

export const getAiUsageStats = onCall({ region }, async (request) => {
  if (!request.auth?.token?.admin) {
    throw new HttpsError(
      "permission-denied",
      "Solo gli admin possono consultare i consumi AI.",
    );
  }

  const now = Date.now();
  const defaultFrom = now - 30 * 24 * 60 * 60 * 1000;
  const fromMs = Number(request.data?.fromMs ?? defaultFrom);
  const toMs = Number(request.data?.toMs ?? now);

  if (!Number.isFinite(fromMs) || !Number.isFinite(toMs) || fromMs > toMs) {
    throw new HttpsError("invalid-argument", "Intervallo date non valido.");
  }

  const fromTs = admin.firestore.Timestamp.fromMillis(fromMs);
  const toTs = admin.firestore.Timestamp.fromMillis(toMs);

  const snap = await admin
    .firestore()
    .collection("ai_usage")
    .where("createdAt", ">=", fromTs)
    .where("createdAt", "<=", toTs)
    .orderBy("createdAt", "desc")
    .limit(5000)
    .get();

  const roleplay = emptyTotals();
  const evaluation = emptyTotals();
  const byUser = new Map<string, UsageTotals>();
  const byDay = new Map<string, UsageTotals>();
  const byModel = new Map<string, UsageTotals>();

  for (const doc of snap.docs) {
    const data = doc.data();
    const type = (data.type ?? "").toString();
    const bucket = type === "evaluation" ? evaluation : roleplay;
    addToTotals(bucket, data);

    const userId = (data.userId ?? "unknown").toString();
    const userTotals = byUser.get(userId) ?? emptyTotals();
    addToTotals(userTotals, data);
    byUser.set(userId, userTotals);

    const createdAt = data.createdAt as admin.firestore.Timestamp | undefined;
    if (createdAt) {
      const dayKey = dayKeyFromTimestamp(createdAt);
      const dayTotals = byDay.get(dayKey) ?? emptyTotals();
      addToTotals(dayTotals, data);
      byDay.set(dayKey, dayTotals);
    }

    const model = (data.model ?? "unknown").toString();
    const modelTotals = byModel.get(model) ?? emptyTotals();
    addToTotals(modelTotals, data);
    byModel.set(model, modelTotals);
  }

  const userRows = [...byUser.entries()]
    .map(([userId, totals]) => {
      const sample = snap.docs.find(
        (doc) => (doc.data().userId ?? "").toString() === userId,
      );
      const email = (sample?.data().userEmail ?? "").toString();
      return mapRow(userId, email || userId, totals);
    })
    .sort((a, b) => b.estimatedCostUsd - a.estimatedCostUsd);

  const dayRows = [...byDay.entries()]
    .map(([day, totals]) => mapRow(day, day, totals))
    .sort((a, b) => a.key.localeCompare(b.key));

  const modelRows = [...byModel.entries()]
    .map(([model, totals]) => mapRow(model, model, totals))
    .sort((a, b) => b.estimatedCostUsd - a.estimatedCostUsd);

  return {
    fromMs,
    toMs,
    scanned: snap.size,
    truncated: snap.size >= 5000,
    roleplay: {
      ...roleplay,
      estimatedCostUsd: Number(roleplay.estimatedCostUsd.toFixed(4)),
    },
    evaluation: {
      ...evaluation,
      estimatedCostUsd: Number(evaluation.estimatedCostUsd.toFixed(4)),
    },
    byUser: userRows,
    byDay: dayRows,
    byModel: modelRows,
  };
});
