import dotenv from "dotenv";

dotenv.config();

export const config = {
  port: Number(process.env.PORT || 3000),
  realtimeWsPort: Number(process.env.REALTIME_WS_PORT || 3002),
  /** true = WS sullo stesso HTTP (Fly/Cloud). false = porta dedicata (Nginx locale). */
  realtimeAttachHttp:
    process.env.REALTIME_ATTACH_HTTP === "true" ||
    String(process.env.REALTIME_WS_PORT || "") === String(process.env.PORT || ""),
  corsOrigin: process.env.CORS_ORIGIN || "*",

  openAiApiKey: process.env.OPENAI_API_KEY || "",
  openAiRealtimeModel:
    process.env.OPENAI_REALTIME_MODEL || "gpt-4o-realtime-preview-2024-12-17",
  openAiRealtimeUrl: "wss://api.openai.com/v1/realtime",

  firebase: {
    projectId: process.env.FIREBASE_PROJECT_ID || "",
    clientEmail: process.env.FIREBASE_CLIENT_EMAIL || "",
    privateKey: (process.env.FIREBASE_PRIVATE_KEY || "").replace(/\\n/g, "\n"),
  },
  requireAuth: process.env.REQUIRE_AUTH !== "false",

  sessionTimeoutMs: Number(process.env.SESSION_TIMEOUT_MS || 20 * 60 * 1000),
  heartbeatIntervalMs: Number(process.env.HEARTBEAT_INTERVAL_MS || 25_000),
  heartbeatTimeoutMs: Number(process.env.HEARTBEAT_TIMEOUT_MS || 45_000),
  upstreamReconnectDelayMs: Number(
    process.env.UPSTREAM_RECONNECT_DELAY_MS || 1_500,
  ),
  upstreamReconnectMaxAttempts: Number(
    process.env.UPSTREAM_RECONNECT_MAX_ATTEMPTS || 2,
  ),
};
