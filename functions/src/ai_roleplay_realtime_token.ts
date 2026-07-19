import { onCall, HttpsError } from "firebase-functions/v2/https";
import { logger } from "firebase-functions";

import { openAiApiKey } from "./openai";

const region = "europe-west1";

/** Modello Realtime API (voce bidirezionale). */
export const OPENAI_REALTIME_MODEL =
  process.env.OPENAI_REALTIME_MODEL?.trim() || "gpt-realtime";

/**
 * Emette un client secret ephemeral OpenAI Realtime.
 * Il client Flutter apre il WebSocket diretto verso OpenAI (niente proxy Fly/VPS).
 */
export const roleplayRealtimeToken = onCall(
  { region, secrets: [openAiApiKey], invoker: "public", timeoutSeconds: 30 },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError(
        "unauthenticated",
        "Accesso richiesto per la simulazione Realtime.",
      );
    }

    const apiKey = openAiApiKey.value()?.trim();
    if (!apiKey) {
      throw new HttpsError(
        "failed-precondition",
        "API OpenAI non configurata sulle Firebase Functions.",
      );
    }

    const model =
      (request.data?.model ?? "").toString().trim() || OPENAI_REALTIME_MODEL;

    const response = await fetch(
      "https://api.openai.com/v1/realtime/client_secrets",
      {
        method: "POST",
        headers: {
          Authorization: `Bearer ${apiKey}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          expires_after: { anchor: "created_at", seconds: 60 },
          session: {
            type: "realtime",
            model,
          },
        }),
      },
    );

    const raw = await response.text();
    if (!response.ok) {
      logger.error("roleplayRealtimeToken OpenAI error", {
        status: response.status,
        body: raw.slice(0, 500),
        uid: request.auth.uid,
      });
      throw new HttpsError(
        "unavailable",
        "Impossibile aprire la sessione Realtime. Riprova.",
      );
    }

    let payload: {
      value?: string;
      expires_at?: number;
      client_secret?: { value?: string; expires_at?: number };
      session?: { model?: string };
    };
    try {
      payload = JSON.parse(raw) as typeof payload;
    } catch {
      throw new HttpsError("internal", "Risposta OpenAI non valida.");
    }

    const token =
      payload.value?.trim() ||
      payload.client_secret?.value?.trim() ||
      "";
    if (!token) {
      throw new HttpsError("internal", "Token Realtime assente nella risposta.");
    }

    const expiresAt =
      payload.expires_at ??
      payload.client_secret?.expires_at ??
      Math.floor(Date.now() / 1000) + 60;

    logger.info("roleplayRealtimeToken minted", {
      uid: request.auth.uid,
      model,
      expiresAt,
    });

    return {
      token,
      expiresAt,
      model,
      wsUrl: `wss://api.openai.com/v1/realtime?model=${encodeURIComponent(model)}`,
    };
  },
);
