#!/usr/bin/env node
/**
 * Smoke test proxy Realtime (eseguire da ai-backend/).
 * Uso: npm run smoke
 *      npm run smoke -- https://ai.creditcore.it wss://ai.creditcore.it/realtime-ws
 */

import WebSocket from "ws";

const httpBase = process.argv[2] || "http://127.0.0.1:3000";
const wsUrl = process.argv[3] || "ws://127.0.0.1:3002";

async function checkHealth() {
  const response = await fetch(`${httpBase}/health`);
  if (!response.ok) {
    throw new Error(`Health HTTP ${response.status}`);
  }
  const body = await response.json();
  if (!body.ok) {
    throw new Error("Health body non ok");
  }
  console.log("OK /health", body);
}

function checkWebSocket() {
  return new Promise((resolve, reject) => {
    const ws = new WebSocket(wsUrl);
    const timer = setTimeout(() => {
      ws.close();
      reject(new Error("Timeout WebSocket"));
    }, 5000);

    ws.on("open", () => {
      clearTimeout(timer);
      ws.close();
      resolve();
    });

    ws.on("error", (error) => {
      clearTimeout(timer);
      reject(error);
    });
  });
}

try {
  await checkHealth();
  await checkWebSocket();
  console.log("OK WebSocket raggiungibile su", wsUrl);
  console.log("Smoke test completato.");
} catch (error) {
  console.error("Smoke test fallito:", error.message);
  process.exit(1);
}
