import cors from "cors";
import express from "express";
import { WebSocketServer } from "ws";

import { initFirebaseAuth } from "./auth.js";
import { config } from "./config.js";
import { attachRealtimeProxy } from "./realtimeProxy.js";

initFirebaseAuth();

const app = express();
app.use(
  cors({
    origin: config.corsOrigin,
    methods: ["GET", "OPTIONS"],
  }),
);

app.get("/health", (_req, res) => {
  res.json({
    ok: true,
    service: "realtime-proxy",
    realtimeWsPort: config.realtimeWsPort,
  });
});

app.listen(config.port, "0.0.0.0", () => {
  console.log(`HTTP health attivo sulla porta ${config.port}`);
});

const realtimeWss = new WebSocketServer({ port: config.realtimeWsPort });
attachRealtimeProxy(realtimeWss);

console.log(
  `WebSocket Realtime proxy attivo sulla porta ${config.realtimeWsPort}`,
);
