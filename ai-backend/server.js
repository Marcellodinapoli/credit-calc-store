import cors from "cors";
import express from "express";
import http from "http";
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
    mode: config.realtimeAttachHttp ? "http+ws" : "split-ports",
  });
});

const httpServer = http.createServer(app);

httpServer.listen(config.port, "0.0.0.0", () => {
  console.log(`HTTP health attivo sulla porta ${config.port}`);
});

/** Su Fly/Cloud un solo porto: WebSocket su /realtime-ws dello stesso server HTTP. */
const attachToHttp =
  config.realtimeAttachHttp || config.realtimeWsPort === config.port;

let realtimeWss;
if (attachToHttp) {
  realtimeWss = new WebSocketServer({
    server: httpServer,
    path: "/realtime-ws",
  });
  console.log(
    `WebSocket Realtime proxy attivo su http://0.0.0.0:${config.port}/realtime-ws`,
  );
} else {
  realtimeWss = new WebSocketServer({ port: config.realtimeWsPort });
  console.log(
    `WebSocket Realtime proxy attivo sulla porta ${config.realtimeWsPort}`,
  );
}

attachRealtimeProxy(realtimeWss);
