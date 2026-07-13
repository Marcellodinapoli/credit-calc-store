# CreditCore Realtime Proxy

Backend minimale per il roleplay vocale **Realtime**: autenticazione Firebase, proxy WebSocket bidirezionale verso OpenAI Realtime API, heartbeat, reconnect upstream e metadati sessione.

**Non contiene:** Ollama, Whisper, Piper, logica roleplay, Chat Completions, recupero crediti, `practiceData`, prompt engineering, `/roleplay-step`, `/roleplay-ws`.

## Separazione rispetto agli altri backend

| Servizio | Dove vive | Ruolo |
|----------|-----------|-------|
| Roleplay GPT | Firebase Function `roleplayStep` | Chat Completions, prompt, simulazioni |
| Analisi telefonata | `ai.creditcore.it/call-analysis` | Endpoint separato (non in questo repo) |
| Ricerca normativa | `ai.creditcore.it` | Endpoint separato (non in questo repo) |
| **Roleplay Realtime** | **questo proxy** `/realtime-ws` | Solo inoltro WebSocket autenticato |

## Architettura

```
Flutter
   │
   ├─ aiProvider=gpt      → Firebase roleplayStep → OpenAI Chat Completions
   │
   └─ aiProvider=realtime → ai-backend /realtime-ws → OpenAI Realtime API
```

## File

| File | Responsabilità |
|------|----------------|
| `server.js` | `GET /health`, WebSocket `/realtime-ws` (porta dedicata) |
| `auth.js` | Verifica Firebase ID Token |
| `realtimeProxy.js` | Proxy bidirezionale OpenAI Realtime |
| `sessionManager.js` | Metadati sessione, cleanup |
| `config.js` | Variabili ambiente centralizzate |

## Protocollo WebSocket

### Bootstrap (client → proxy)

```json
{
  "type": "session.bootstrap",
  "sessionId": "sim-abc-123",
  "idToken": "<Firebase ID token>",
  "provider": "realtime",
  "sessionUpdate": {
    "type": "session.update",
    "session": { "...": "costruito interamente da Flutter" }
  }
}
```

Il proxy:
1. verifica `idToken`
2. apre OpenAI Realtime
3. inoltra `sessionUpdate` **senza modificarlo**
4. risponde `{ "type": "proxy.ready", "sessionId": "..." }`

### Eventi successivi

Inoltro bidirezionale integrale degli eventi OpenAI Realtime.

### Heartbeat

- Proxy → client: `{ "type": "proxy.ping", "ts": ... }`
- Client → proxy: `{ "type": "proxy.pong" }`

### Reconnect upstream

Se OpenAI chiude inaspettatamente, il proxy tenta fino a `UPSTREAM_RECONNECT_MAX_ATTEMPTS` riconnessioni e notifica:

```json
{ "type": "proxy.reconnecting", "attempt": 1, "maxAttempts": 2 }
```

### Stop

```json
{ "type": "session.stop", "sessionId": "..." }
```

## Avvio

```bash
cd ai-backend
cp .env.example .env
npm install
npm start
```

## Deploy produzione

Guida completa: [`docs/roleplay_realtime_deploy.md`](../docs/roleplay_realtime_deploy.md)

```bash
npm ci --omit=dev
pm2 start ecosystem.config.cjs
pm2 save
npm run smoke -- https://ai.creditcore.it wss://ai.creditcore.it/realtime-ws
```

Nginx: vedere `deploy/nginx-ai-creditcore.conf`.

## Nginx (produzione)

```nginx
location /realtime-ws {
  proxy_pass http://127.0.0.1:3002;
  proxy_http_version 1.1;
  proxy_set_header Upgrade $http_upgrade;
  proxy_set_header Connection "Upgrade";
  proxy_read_timeout 86400;
}
```
