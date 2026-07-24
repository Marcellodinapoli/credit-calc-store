import * as admin from "firebase-admin";
import { onCall, HttpsError } from "firebase-functions/v2/https";

const region = "europe-west1";
const MAX_EVENTS = 5000;
const USD_TO_EUR = 0.92;

type Totals = {
  calls: number;
  inputTokens: number;
  outputTokens: number;
  totalTokens: number;
  estimatedCostUsd: number;
  errors: number;
};

type BreakdownRow = Totals & {
  key: string;
  label: string;
};

/** Dove viene usata l'AI + modello OpenAI associato. */
const FEATURE_META: Array<{
  key: string;
  label: string;
  model: string;
  aliases?: string[];
}> = [
  {
    key: "roleplayStep",
    label: "Role Play (Chat)",
    model: "gpt-5.5",
    aliases: ["roleplaySuggestion", "roleplay"],
  },
  {
    key: "roleplayRealtime",
    label: "Role Play (Realtime)",
    model: "gpt-realtime",
    aliases: ["realtime"],
  },
  {
    key: "warmupEvaluate",
    label: "Warm-up / Valutazione",
    model: "gpt-5.5",
    aliases: ["evaluation", "warmup"],
  },
  {
    key: "contestationGenerate",
    label: "Contestazioni",
    model: "gpt-5.5",
    aliases: ["contestation"],
  },
  {
    key: "normativeSearch",
    label: "Ricerca normativa",
    model: "gpt-4.1",
  },
  {
    key: "callAnalysis",
    label: "Analisi telefonata",
    model: "gpt-4.1",
  },
];

function emptyTotals(): Totals {
  return {
    calls: 0,
    inputTokens: 0,
    outputTokens: 0,
    totalTokens: 0,
    estimatedCostUsd: 0,
    errors: 0,
  };
}

function asInt(value: unknown): number {
  if (typeof value === "number" && Number.isFinite(value)) {
    return Math.max(0, Math.floor(value));
  }
  if (typeof value === "string") {
    const parsed = parseInt(value, 10);
    return Number.isFinite(parsed) ? Math.max(0, parsed) : 0;
  }
  return 0;
}

function asFloat(value: unknown): number {
  if (typeof value === "number" && Number.isFinite(value)) {
    return Math.max(0, value);
  }
  if (typeof value === "string") {
    const parsed = parseFloat(value);
    return Number.isFinite(parsed) ? Math.max(0, parsed) : 0;
  }
  return 0;
}

function addTotals(target: Totals, delta: Partial<Totals>): void {
  target.calls += asInt(delta.calls);
  target.inputTokens += asInt(delta.inputTokens);
  target.outputTokens += asInt(delta.outputTokens);
  target.totalTokens += asInt(delta.totalTokens);
  target.estimatedCostUsd += asFloat(delta.estimatedCostUsd);
  target.errors += asInt(delta.errors);
}

function eurToUsd(eur: number): number {
  return eur / USD_TO_EUR;
}

function monthKeysBetween(fromMs: number, toMs: number): string[] {
  const keys: string[] = [];
  const cursor = new Date(fromMs);
  cursor.setUTCDate(1);
  cursor.setUTCHours(0, 0, 0, 0);
  const end = new Date(toMs);
  end.setUTCDate(1);
  end.setUTCHours(0, 0, 0, 0);

  while (cursor.getTime() <= end.getTime()) {
    const month = String(cursor.getUTCMonth() + 1).padStart(2, "0");
    keys.push(`${cursor.getUTCFullYear()}-${month}`);
    cursor.setUTCMonth(cursor.getUTCMonth() + 1);
  }
  return keys;
}

function resolveFeatureKey(raw: string): string | null {
  const value = raw.trim().toLowerCase();
  if (!value) return null;
  for (const meta of FEATURE_META) {
    if (meta.key.toLowerCase() === value) return meta.key;
    if (meta.aliases?.some((a) => a.toLowerCase() === value)) return meta.key;
  }
  return null;
}

function featureLabel(key: string): string {
  return FEATURE_META.find((m) => m.key === key)?.label ?? key;
}

function featureModel(key: string): string {
  return FEATURE_META.find((m) => m.key === key)?.model ?? "unknown";
}

function eventTimestampMs(data: Record<string, unknown>): number | null {
  const created = data.createdAt ?? data.timestamp ?? data.at;
  if (
    created
    && typeof created === "object"
    && created !== null
    && "toMillis" in created
    && typeof (created as { toMillis: () => number }).toMillis === "function"
  ) {
    return (created as { toMillis: () => number }).toMillis();
  }
  if (typeof created === "number" && Number.isFinite(created)) {
    return created;
  }
  return null;
}

function upsertBreakdown(
  map: Map<string, BreakdownRow>,
  key: string,
  label: string,
  delta: Totals,
): void {
  const existing = map.get(key) ?? {
    key,
    label,
    ...emptyTotals(),
  };
  addTotals(existing, delta);
  if (!existing.label && label) existing.label = label;
  map.set(key, existing);
}

function sortRows(rows: BreakdownRow[]): BreakdownRow[] {
  return rows.sort((a, b) => b.estimatedCostUsd - a.estimatedCostUsd
    || b.calls - a.calls
    || a.key.localeCompare(b.key));
}

function featureFromMonthDoc(
  data: Record<string, unknown>,
  featureKeys: string[],
): Totals {
  const totals = emptyTotals();
  const nestedFeatures = data.features;
  const nestedMap =
    nestedFeatures && typeof nestedFeatures === "object"
      ? (nestedFeatures as Record<string, unknown>)
      : null;

  for (const key of featureKeys) {
    const nested = nestedMap?.[key];
    if (nested && typeof nested === "object") {
      const row = nested as Record<string, unknown>;
      const inputTokens = asInt(row.inputTokens);
      const outputTokens = asInt(row.outputTokens);
      addTotals(totals, {
        calls: asInt(row.calls),
        inputTokens,
        outputTokens,
        totalTokens: inputTokens + outputTokens,
        estimatedCostUsd: 0,
        errors: 0,
      });
      continue;
    }

    const inputTokens = asInt(data[`features.${key}.inputTokens`]);
    const outputTokens = asInt(data[`features.${key}.outputTokens`]);
    addTotals(totals, {
      calls: asInt(data[`features.${key}.calls`]),
      inputTokens,
      outputTokens,
      totalTokens: inputTokens + outputTokens,
      estimatedCostUsd: 0,
      errors: 0,
    });
  }
  return totals;
}

function monthEstimatedEur(data: Record<string, unknown>): number {
  const nested = data.totals;
  if (nested && typeof nested === "object") {
    const eur = asFloat((nested as Record<string, unknown>).estimatedEur);
    if (eur > 0) return eur;
  }
  return asFloat(data["totals.estimatedEur"]);
}

function monthTokenDenom(data: Record<string, unknown>, fallback: number): number {
  const nestedTotals = data.totals;
  const nestedTokenSum =
    nestedTotals && typeof nestedTotals === "object"
      ? asInt((nestedTotals as Record<string, unknown>).inputTokens)
        + asInt((nestedTotals as Record<string, unknown>).outputTokens)
      : 0;
  const flatTokenSum =
    asInt(data["totals.inputTokens"]) + asInt(data["totals.outputTokens"]);
  if (nestedTokenSum > 0) return nestedTokenSum;
  if (flatTokenSum > 0) return flatTokenSum;
  return fallback > 0 ? fallback : 1;
}

function accumulateEvent(
  data: Record<string, unknown>,
  byFeature: Map<string, BreakdownRow>,
  byUser: Map<string, BreakdownRow>,
  byDay: Map<string, BreakdownRow>,
  byModel: Map<string, BreakdownRow>,
): void {
  const rawFeature = (
    data.feature
    ?? data.kind
    ?? data.category
    ?? data.type
    ?? ""
  ).toString();
  const featureKey = resolveFeatureKey(rawFeature);
  if (!featureKey) return;

  const inputTokens = asInt(data.inputTokens ?? data.promptTokens);
  const outputTokens = asInt(data.outputTokens ?? data.completionTokens);
  const totalTokens = asInt(data.totalTokens) || inputTokens + outputTokens;
  const estimatedCostUsd = asFloat(data.estimatedCostUsd)
    || eurToUsd(asFloat(data.estimatedCostEur ?? data.estimatedEur));
  const errors = data.error === true || data.ok === false ? 1 : asInt(data.errors);
  const delta: Totals = {
    calls: 1,
    inputTokens,
    outputTokens,
    totalTokens,
    estimatedCostUsd,
    errors,
  };

  upsertBreakdown(byFeature, featureKey, featureLabel(featureKey), delta);

  const userId = (data.userId ?? data.uid ?? "unknown").toString();
  const userLabel = (data.userEmail ?? data.email ?? userId).toString();
  upsertBreakdown(byUser, userId, userLabel, delta);

  const ts = eventTimestampMs(data);
  if (ts != null) {
    const day = new Date(ts).toISOString().slice(0, 10);
    upsertBreakdown(byDay, day, day, delta);
  }

  const model = (data.model ?? featureModel(featureKey)).toString().trim()
    || "unknown";
  upsertBreakdown(byModel, model, model, delta);
}

/**
 * Aggrega i log `ai_usage` (eventi) e, se assenti, i totali mensili
 * in `settings/ai_usage/months` per area (feature) e modello OpenAI.
 */
export const getAiUsageStats = onCall(
  { region, timeoutSeconds: 60 },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Accesso richiesto.");
    }
    if (request.auth.token.admin !== true) {
      throw new HttpsError(
        "permission-denied",
        "Solo gli admin possono consultare i consumi AI.",
      );
    }

    const fromMs = asInt(request.data?.fromMs);
    const toMs = asInt(request.data?.toMs);
    if (!fromMs || !toMs || toMs < fromMs) {
      throw new HttpsError(
        "invalid-argument",
        "Intervallo date non valido (fromMs/toMs).",
      );
    }

    const byFeature = new Map<string, BreakdownRow>();
    const byUser = new Map<string, BreakdownRow>();
    const byDay = new Map<string, BreakdownRow>();
    const byModel = new Map<string, BreakdownRow>();

    const db = admin.firestore();
    let scanned = 0;
    let truncated = false;

    try {
      const snap = await db
        .collection("ai_usage")
        .where("createdAt", ">=", admin.firestore.Timestamp.fromMillis(fromMs))
        .where("createdAt", "<=", admin.firestore.Timestamp.fromMillis(toMs))
        .orderBy("createdAt", "desc")
        .limit(MAX_EVENTS)
        .get();

      scanned = snap.size;
      truncated = snap.size >= MAX_EVENTS;
      for (const doc of snap.docs) {
        accumulateEvent(
          doc.data() as Record<string, unknown>,
          byFeature,
          byUser,
          byDay,
          byModel,
        );
      }
    } catch (error) {
      console.warn("getAiUsageStats: event query skipped", error);
    }

    const hasEvents = [...byFeature.values()].some((row) => row.calls > 0);
    if (!hasEvents) {
      const monthKeys = monthKeysBetween(fromMs, toMs);
      let monthScanned = 0;
      for (const key of monthKeys) {
        const doc = await db
          .collection("settings")
          .doc("ai_usage")
          .collection("months")
          .doc(key)
          .get();
        if (!doc.exists) continue;
        monthScanned += 1;
        const data = (doc.data() ?? {}) as Record<string, unknown>;
        const monthUsd = eurToUsd(monthEstimatedEur(data));

        const featureTotals = new Map<string, Totals>();
        let featureTokenSum = 0;
        for (const meta of FEATURE_META) {
          const trackerKeys = [meta.key];
          if (meta.key === "roleplayStep") {
            trackerKeys.push("roleplaySuggestion");
          }
          const totals = featureFromMonthDoc(data, trackerKeys);
          if (totals.calls <= 0 && totals.totalTokens <= 0) continue;
          featureTotals.set(meta.key, totals);
          featureTokenSum += totals.totalTokens;
        }

        const denom = monthTokenDenom(data, featureTokenSum);
        const dayDelta = emptyTotals();

        for (const [featureKey, totals] of featureTotals) {
          if (featureTokenSum > 0 && monthUsd > 0) {
            totals.estimatedCostUsd = monthUsd * (totals.totalTokens / denom);
          }
          upsertBreakdown(
            byFeature,
            featureKey,
            featureLabel(featureKey),
            totals,
          );
          const model = featureModel(featureKey);
          upsertBreakdown(byModel, model, model, totals);
          addTotals(dayDelta, totals);
        }

        if (dayDelta.calls > 0) {
          upsertBreakdown(byDay, `${key}-01`, key, dayDelta);
        }
      }
      scanned = monthScanned;
    }

    const roleplay = emptyTotals();
    const evaluation = emptyTotals();
    addTotals(roleplay, byFeature.get("roleplayStep") ?? emptyTotals());
    addTotals(roleplay, byFeature.get("roleplaySuggestion") ?? emptyTotals());
    addTotals(roleplay, byFeature.get("roleplayRealtime") ?? emptyTotals());
    addTotals(evaluation, byFeature.get("warmupEvaluate") ?? emptyTotals());
    addTotals(evaluation, byFeature.get("contestationGenerate") ?? emptyTotals());

    // Ordine stabile per area (come FEATURE_META), poi eventuale resto.
    const byFeatureOrdered: BreakdownRow[] = [];
    for (const meta of FEATURE_META) {
      const row = byFeature.get(meta.key);
      if (row) byFeatureOrdered.push(row);
    }
    for (const row of byFeature.values()) {
      if (!byFeatureOrdered.some((r) => r.key === row.key)) {
        byFeatureOrdered.push(row);
      }
    }

    return {
      fromMs,
      toMs,
      scanned,
      truncated,
      roleplay,
      evaluation,
      byFeature: byFeatureOrdered,
      byUser: sortRows([...byUser.values()]),
      byDay: sortRows([...byDay.values()]).sort((a, b) =>
        a.key.localeCompare(b.key)
      ),
      byModel: sortRows([...byModel.values()]),
    };
  },
);
