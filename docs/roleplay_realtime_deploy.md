# Fase 7 — Deploy controllato Realtime

## Architettura produzione

```
Flutter (app / web)
      ↓  WSS
wss://ai.creditcore.it/realtime-ws
      ↓
Nginx (TLS termination + WebSocket upgrade)
      ↓
ai-backend (Node, porta 3002 WS + 3000 HTTP health)
      ↓
OpenAI Realtime API
```

Il ramo GPT resta su Firebase (`roleplayStep`) e **non** passa da questo proxy.

---

## Dove è ospitato oggi

Dal codice dell'app, **tutti i backend AI HTTP** puntano già a un unico dominio:

| Servizio | Endpoint |
|----------|----------|
| Analisi telefonata | `https://ai.creditcore.it/call-analysis` |
| Ricerca normativa | `https://ai.creditcore.it/normative-search` |
| Directory / altri | `https://ai.creditcore.it/...` |
| **Roleplay Realtime (nuovo)** | `wss://ai.creditcore.it/realtime-ws` |

**Conclusione operativa:** il proxy Realtime va deployato **sullo stesso host** che serve già `ai.creditcore.it`, dietro lo stesso Nginx/reverse proxy. Non esiste un percorso deploy separato nel repository.

> Verifica sul server: `curl https://ai.creditcore.it/health` dopo il deploy.

---

## Prima del deploy (SSH sul server)

Eseguire il preflight:

```bash
cd /opt/creditcore/ai-backend   # dopo la copia
bash deploy/server_preflight.sh
```

Verifiche manuali essenziali:

```bash
pm2 list
systemctl status nginx
sudo ss -tulpn | grep -E '3000|3002'
grep -r 'realtime-ws\|call-analysis' /etc/nginx/
```

La porta **3002** deve essere libera (o già usata solo da questo proxy).
Nginx deve avere `Upgrade` + `Connection "upgrade"` su `/realtime-ws`.

---

## Deploy del proxy (checklist)

### 1. Copia codice sul server

```bash
# Esempio: directory sul server
/opt/creditcore/ai-backend
```

Trasferire la cartella `ai-backend/` del repo (esclusi `node_modules/`).

### 2. Configurazione ambiente

```bash
cd /opt/creditcore/ai-backend
cp .env.example .env
nano .env
```

Variabili obbligatorie in produzione:

```env
PORT=3000
REALTIME_WS_PORT=3002
REQUIRE_AUTH=true
OPENAI_API_KEY=sk-...
OPENAI_REALTIME_MODEL=gpt-4o-realtime-preview-2024-12-17
FIREBASE_PROJECT_ID=creditform-d505d
FIREBASE_CLIENT_EMAIL=...
FIREBASE_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----\n"
```

### 3. Installazione e avvio

```bash
npm ci --omit=dev
pm2 start ecosystem.config.cjs
pm2 save
pm2 startup
```

### 4. Nginx

Aggiungere al virtual host `ai.creditcore.it` (file di riferimento: `deploy/nginx-ai-creditcore.conf`):

- `GET /health` → `127.0.0.1:3000`
- `WSS /realtime-ws` → `127.0.0.1:3002`

```bash
sudo nginx -t && sudo systemctl reload nginx
```

### 5. Smoke test (ordine corretto post-deploy)

```bash
# 1. Health HTTP
curl https://ai.creditcore.it/health

# 2. WebSocket
cd /opt/creditcore/ai-backend
npm run smoke -- https://ai.creditcore.it wss://ai.creditcore.it/realtime-ws

# 3. Simulazione reale (un solo utente, app in debug)
#    → log RoleplayRealtime QA: latenza apertura / turni

# 4. Solo dopo stabilità: rate limit, piani, tracking costi
```

---

## Sicurezza deploy

| Controllo | Azione |
|-----------|--------|
| API key | solo in `.env`, mai in log/git |
| Firebase | service account dedicato al proxy |
| TLS | certificato valido su `ai.creditcore.it` |
| Firewall | porte 3000/3002 solo localhost; esposto solo Nginx 443 |
| Log | `pm2 logs credit-realtime-proxy` — verificare assenza `sk-` |

---

## Post-deploy (non bloccanti per go-live tecnico)

| Item | Stato |
|------|-------|
| Test audio reale (web + native) | Manuale |
| Verifica latenza (< 2s / < 1s) | Log QA debug |
| Rate limit per UID | Da implementare |
| Tracking costi OpenAI Realtime | Da implementare |
| Limiti minuti per piano | Da implementare (Firestore) |

---

## Rollback

```bash
pm2 stop credit-realtime-proxy
# oppure ripristino versione precedente + pm2 restart credit-realtime-proxy
```

Le simulazioni `gpt` / senza provider **non sono impattate** (Firebase diretto).

---

## Sviluppo locale

```bash
cd ai-backend
cp .env.example .env   # REQUIRE_AUTH=false per test locali
npm install
npm start
npm run smoke          # http://127.0.0.1:3000 + ws://127.0.0.1:3002
```

Flutter web in HTTP locale usa `ws://127.0.0.1:3002`.  
App native e web HTTPS usano `wss://ai.creditcore.it/realtime-ws`.
