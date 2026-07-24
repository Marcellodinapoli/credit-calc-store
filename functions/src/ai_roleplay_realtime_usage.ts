import { onCall, HttpsError } from "firebase-functions/v2/https";

import {
  modalityFromRealtimeUsage,
  trackAiUsage,
} from "./ai_usage_tracker";

const region = "europe-west1";

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

/**
 * Registra usage di un turno Realtime (`response.done.response.usage`)
 * inviato dal client Flutter dopo ogni risposta.
 */
export const trackRoleplayRealtimeUsage = onCall(
  { region, timeoutSeconds: 30 },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError(
        "unauthenticated",
        "Accesso richiesto per tracciare il consumo Realtime.",
      );
    }

    const model =
      (request.data?.model ?? "").toString().trim() || "gpt-realtime";
    const usageRaw = request.data?.usage;
    if (!usageRaw || typeof usageRaw !== "object") {
      throw new HttpsError(
        "invalid-argument",
        "Campo usage Realtime mancante.",
      );
    }

    const usage = usageRaw as Record<string, unknown>;
    const modality = modalityFromRealtimeUsage(usage);
    const inputTokens = asInt(usage.input_tokens);
    const outputTokens = asInt(usage.output_tokens);
    const totalTokens = asInt(usage.total_tokens)
      || inputTokens + outputTokens;

    if (inputTokens <= 0 && outputTokens <= 0 && totalTokens <= 0) {
      return { ok: true, skipped: true };
    }

    trackAiUsage({
      feature: "roleplayRealtime",
      userId: request.auth.uid,
      userEmail: request.auth.token.email,
      model,
      inputTokens,
      outputTokens,
      totalTokens,
      modality,
    });

    return { ok: true };
  },
);
