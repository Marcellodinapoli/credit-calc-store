import { openAiAdminApiKey, openAiApiKey } from "./openai";

export type OpenAiOfficialCost = {
  available: boolean;
  totalUsd: number;
  currency: string;
  buckets: number;
  /** Fine ultimo giorno con dato costi (ms). OpenAI Costs spesso ritarda ~1 giorno. */
  throughMs?: number;
  source: "openai_organization_costs";
  error?: string;
};

type CostBucket = {
  start_time?: number;
  end_time?: number;
  results?: Array<{
    amount?: { value?: number; currency?: string };
  }>;
};

type CostsPage = {
  data?: CostBucket[];
  has_more?: boolean;
  next_page?: string | null;
};

/** Rimuove spazi, virgolette e newline tipici di paste Windows. */
function sanitizeApiKey(raw: string | undefined | null): string | null {
  if (!raw) return null;
  const cleaned = raw
    .replace(/^\uFEFF/, "")
    .trim()
    .replace(/^["']+|["']+$/g, "")
    .replace(/[\r\n\t]/g, "")
    .trim();
  return cleaned || null;
}

function keyDebug(apiKey: string): string {
  const prefix = apiKey.slice(0, 12);
  return `prefix=${prefix}… len=${apiKey.length}`;
}

function resolveAdminKey(): string | null {
  try {
    const admin = sanitizeApiKey(openAiAdminApiKey.value());
    if (admin) return admin;
  } catch {
    // Secret non montato su questa function.
  }
  try {
    const fallback = sanitizeApiKey(openAiApiKey.value());
    if (fallback) return fallback;
  } catch {
    // ignore
  }
  return sanitizeApiKey(process.env.OPENAI_ADMIN_API_KEY)
    || sanitizeApiKey(process.env.OPENAI_API_KEY);
}

/**
 * Costo ufficiale organizzazione OpenAI (come Usage → Costs nel dashboard).
 * Richiede Admin API key. Pagina con bucket giornalieri.
 */
export async function fetchOpenAiOrganizationCosts(params: {
  fromMs: number;
  toMs: number;
}): Promise<OpenAiOfficialCost> {
  const apiKey = resolveAdminKey();
  if (!apiKey) {
    return {
      available: false,
      totalUsd: 0,
      currency: "usd",
      buckets: 0,
      source: "openai_organization_costs",
        error:
          "Manca OPENAI_API_KEY (Admin) su Firebase. "
          + "Per i costi ufficiali serve una Admin API key OpenAI.",
    };
  }

  const startTime = Math.floor(params.fromMs / 1000);
  // end_time esclusivo: +1s rispetto a toMs
  const endTime = Math.floor(params.toMs / 1000) + 1;

  let totalUsd = 0;
  let currency = "usd";
  let buckets = 0;
  let lastBucketEndSec = 0;
  let lastCostedEndSec = 0;
  let page: string | null = null;
  let pages = 0;

  try {
    do {
      const url = new URL("https://api.openai.com/v1/organization/costs");
      url.searchParams.set("start_time", String(startTime));
      url.searchParams.set("end_time", String(endTime));
      url.searchParams.set("bucket_width", "1d");
      url.searchParams.set("limit", "180");
      if (page) {
        url.searchParams.set("page", page);
      }

      const response = await fetch(url.toString(), {
        method: "GET",
        headers: {
          Authorization: `Bearer ${apiKey}`,
          "Content-Type": "application/json",
        },
      });

      const raw = await response.text();
      if (!response.ok) {
        const hint =
          response.status === 401 || response.status === 403
            ? " Chiave Admin non valida o incompleta (non usare la project key)."
            : "";
        return {
          available: false,
          totalUsd: 0,
          currency: "usd",
          buckets: 0,
          source: "openai_organization_costs",
          error:
            `OpenAI costs HTTP ${response.status}.${hint} `
            + `(${keyDebug(apiKey)}) ${raw.slice(0, 160)}`,
        };
      }

      const payload = JSON.parse(raw) as CostsPage;
      for (const bucket of payload.data ?? []) {
        buckets += 1;
        let dayUsd = 0;
        for (const result of bucket.results ?? []) {
          const value = Number(result.amount?.value ?? 0);
          if (Number.isFinite(value)) {
            dayUsd += value;
            totalUsd += value;
          }
          const cur = result.amount?.currency?.toLowerCase();
          if (cur) currency = cur;
        }
        const bucketEnd = Number(bucket.end_time ?? 0);
        if (bucketEnd > lastBucketEndSec) {
          lastBucketEndSec = bucketEnd;
        }
        if (dayUsd > 0 && bucketEnd > lastCostedEndSec) {
          lastCostedEndSec = bucketEnd;
        }
      }

      page = payload.has_more ? (payload.next_page ?? null) : null;
      pages += 1;
    } while (page && pages < 20);

    const throughSec = lastCostedEndSec || lastBucketEndSec;

    return {
      available: true,
      totalUsd: Number(totalUsd.toFixed(6)),
      currency,
      buckets,
      throughMs: throughSec > 0 ? throughSec * 1000 : undefined,
      source: "openai_organization_costs",
    };
  } catch (error) {
    return {
      available: false,
      totalUsd: 0,
      currency: "usd",
      buckets: 0,
      source: "openai_organization_costs",
      error: error instanceof Error ? error.message : String(error),
    };
  }
}
