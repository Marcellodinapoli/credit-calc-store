import WebSocket from "ws";

import { config } from "./config.js";
import { verifyAuthToken } from "./auth.js";
import {
  appendHistory,
  closeSession,
  createSession,
  touchHeartbeat,
  touchSession,
} from "./sessionManager.js";

function sendJson(ws, payload) {
  if (ws.readyState === WebSocket.OPEN) {
    ws.send(JSON.stringify(payload));
  }
}

function forwardIfOpen(target, data) {
  if (target?.readyState === WebSocket.OPEN) {
    target.send(data);
  }
}

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

export function attachRealtimeProxy(wss) {
  wss.on("connection", (clientWs) => {
    let upstream = null;
    let sessionId = "default";
    let bootstrapped = false;
    let bootstrapPayload = null;
    let reconnectAttempts = 0;
    let heartbeatTimer = null;
    let heartbeatWatchdog = null;
    let closing = false;

    const clearHeartbeat = () => {
      if (heartbeatTimer) clearInterval(heartbeatTimer);
      if (heartbeatWatchdog) clearInterval(heartbeatWatchdog);
      heartbeatTimer = null;
      heartbeatWatchdog = null;
    };

    const closeBoth = (reason = "") => {
      if (closing) return;
      closing = true;
      clearHeartbeat();
      try {
        if (reason) {
          sendJson(clientWs, { type: "proxy.error", message: reason });
        }
      } catch (_) {}
      try {
        upstream?.close();
      } catch (_) {}
      try {
        clientWs.close();
      } catch (_) {}
      if (bootstrapped) closeSession(sessionId);
    };

    const startHeartbeat = () => {
      clearHeartbeat();
      heartbeatTimer = setInterval(() => {
        sendJson(clientWs, {
          type: "proxy.ping",
          ts: Date.now(),
        });
      }, config.heartbeatIntervalMs);

      heartbeatWatchdog = setInterval(() => {
        const session = touchSession(sessionId);
        if (!session) return;
        const idleMs = Date.now() - (session.lastHeartbeatAt || session.updatedAt);
        if (idleMs > config.heartbeatTimeoutMs) {
          closeBoth("Heartbeat scaduto.");
        }
      }, config.heartbeatIntervalMs);
    };

    const connectUpstream = async () => {
      const apiKey = config.openAiApiKey;
      if (!apiKey) {
        throw new Error("OPENAI_API_KEY non configurata sul server.");
      }

      const model = bootstrapPayload?.model || config.openAiRealtimeModel;
      const url = `${config.openAiRealtimeUrl}?model=${encodeURIComponent(model)}`;

      upstream = new WebSocket(url, {
        headers: {
          Authorization: `Bearer ${apiKey}`,
          "OpenAI-Beta": "realtime=v1",
        },
      });

      upstream.on("open", () => {
        reconnectAttempts = 0;
        touchSession(sessionId, { callState: "active" });

        if (bootstrapPayload?.sessionUpdate) {
          forwardIfOpen(
            upstream,
            JSON.stringify(bootstrapPayload.sessionUpdate),
          );
        }

        sendJson(clientWs, { type: "proxy.ready", sessionId });
        startHeartbeat();
      });

      upstream.on("message", (data) => {
        forwardIfOpen(clientWs, data.toString());

        try {
          const event = JSON.parse(data.toString());
          const eventType = event?.type || "";

          if (eventType === "response.audio_transcript.done") {
            appendHistory(sessionId, "assistant", event.transcript || "");
          }

          if (
            eventType ===
            "conversation.item.input_audio_transcription.completed"
          ) {
            appendHistory(sessionId, "user", event.transcript || "");
          }

          if (eventType === "error") {
            sendJson(clientWs, {
              type: "proxy.error",
              message: event?.error?.message || "Errore Realtime.",
            });
          }
        } catch (_) {}
      });

      upstream.on("error", () => {
        closeBoth("Errore connessione OpenAI Realtime.");
      });

      upstream.on("close", async () => {
        if (closing) return;

        if (
          bootstrapped &&
          reconnectAttempts < config.upstreamReconnectMaxAttempts
        ) {
          reconnectAttempts += 1;
          sendJson(clientWs, {
            type: "proxy.reconnecting",
            attempt: reconnectAttempts,
            maxAttempts: config.upstreamReconnectMaxAttempts,
          });
          await sleep(config.upstreamReconnectDelayMs);
          try {
            await connectUpstream();
            return;
          } catch (_) {
            // fall through to close
          }
        }

        closeSession(sessionId);
        sendJson(clientWs, {
          type: "proxy.disconnected",
          reconnectable: false,
        });
        try {
          clientWs.close();
        } catch (_) {}
      });
    };

    clientWs.on("message", async (message) => {
      let payload;
      try {
        payload = JSON.parse(message.toString());
      } catch (_) {
        sendJson(clientWs, {
          type: "proxy.error",
          message: "Messaggio non valido.",
        });
        return;
      }

      const type = payload?.type || "";

      if (type === "proxy.pong") {
        if (bootstrapped) touchHeartbeat(sessionId);
        return;
      }

      if (bootstrapped) {
        touchHeartbeat(sessionId);
      }

      if (type === "session.bootstrap") {
        try {
          const { uid } = await verifyAuthToken(payload.idToken);
          sessionId = payload.sessionId || `rt-${Date.now()}`;
          bootstrapped = true;
          bootstrapPayload = payload;

          createSession({
            sessionId,
            userId: uid,
            provider: payload.provider || "realtime",
          });

          await connectUpstream();
        } catch (error) {
          closeBoth(error?.message || "Autenticazione non valida.");
        }
        return;
      }

      if (type === "session.stop") {
        closeSession(sessionId);
        try {
          upstream?.close();
        } catch (_) {}
        return;
      }

      if (!upstream || upstream.readyState !== WebSocket.OPEN) {
        sendJson(clientWs, {
          type: "proxy.error",
          message: "Sessione Realtime non pronta.",
        });
        return;
      }

      forwardIfOpen(upstream, JSON.stringify(payload));
    });

    clientWs.on("close", () => {
      if (bootstrapped) closeSession(sessionId);
      clearHeartbeat();
      try {
        upstream?.close();
      } catch (_) {}
    });

    clientWs.on("error", () => {
      closeBoth();
    });
  });
}
