# Roleplay Realtime — Roadmap e promemoria

> Usare questo file quando si lavora dal PC di casa (SSH al server disponibile).

---

## Completato

- [x] Architettura GPT vs Realtime definita
- [x] Separazione motori: `RoleplayGptSession` / `RoleplayRealtimeSession`
- [x] Factory provider (`gpt`, `realtime`, `hetzner`→`gpt`)
- [x] Backend proxy `ai-backend/` (health + WSS + auth Firebase)
- [x] Astrazione sessione Flutter (`RoleplaySession`, eventi, status)
- [x] Test codice (`roleplay_ai_provider_test`, factory, session config)
- [x] Config produzione: `wss://ai.creditcore.it/realtime-ws`
- [x] Pulizia riferimenti IP/Hetzner operativi
- [x] Script preflight: `ai-backend/deploy/server_preflight.sh`
- [x] Guida deploy: `docs/roleplay_realtime_deploy.md`
- [x] Checklist QA: `docs/roleplay_realtime_qa.md`

---

## Da fare (in ordine)

### Fase A — SSH + deploy `ai-backend` *(prossimo passo)*

**Prerequisito:** accesso SSH al server che serve `ai.creditcore.it`.

```bash
# Ricognizione
pm2 list
systemctl status nginx
sudo ss -tulpn | grep -E '3000|3002'
grep -r 'ai.creditcore.it\|call-analysis\|realtime-ws' /etc/nginx/
```

```bash
# Copia cartella ai-backend/ sul server → es. /opt/creditcore/ai-backend
cd /opt/creditcore/ai-backend
bash deploy/server_preflight.sh
cp .env.example .env          # OPENAI_API_KEY + Firebase service account
npm ci --omit=dev
pm2 start ecosystem.config.cjs
pm2 save
```

```bash
# Nginx — aggiungere deploy/nginx-ai-creditcore.conf al vhost esistente
sudo nginx -t && sudo systemctl reload nginx
```

```bash
# Verifica immediata
curl https://ai.creditcore.it/health
npm run smoke -- https://ai.creditcore.it wss://ai.creditcore.it/realtime-ws
```

**Checklist deploy:**

- [ ] Porta 3002 libera
- [ ] Nginx con `Upgrade` + `Connection "upgrade"` su `/realtime-ws`
- [ ] `.env` con `REQUIRE_AUTH=true`
- [ ] PM2 avviato e persistente (`pm2 save` + `pm2 startup`)
- [ ] `/health` risponde `ok: true`
- [ ] Smoke WSS OK

---

### Fase B — Prima simulazione vocale reale

- [ ] Firestore: simulazione test con `aiProvider: "realtime"`
- [ ] App autenticata (token Firebase valido)
- [ ] Avviare simulazione → microfono attivo
- [ ] Verificare risposta vocale del cliente simulato
- [ ] Verificare chiusura pulita (stop sessione, nessun leak WS)
- [ ] Verificare che `aiProvider: "gpt"` continui a funzionare come prima

Dettaglio scenari: `docs/roleplay_realtime_qa.md`

---

### Fase C — Controllo latenza e stabilità

**Solo dopo almeno una simulazione reale riuscita.**

- [ ] Log debug `RoleplayRealtime QA:` — tempo apertura sessione
- [ ] Latenza turno vocale (input → risposta audio)
- [ ] Test interrupt (parlare sopra la risposta)
- [ ] Sessione lunga (~5 min) senza disconnessioni
- [ ] Test su web e, se possibile, su mobile nativo
- [ ] Analisi log server (`pm2 logs`) per errori upstream OpenAI

**Non procedere alla Fase D finché Realtime non è stabile.**

---

### Fase D — Rate limit + tracking costi *(dopo stabilità)*

- [ ] Rate limit per UID (sessioni concorrenti / minuto)
- [ ] Limiti per piano (Free / Plus / Azienda)
- [ ] Tracking costi OpenAI (token/audio, per sessione/utente)
- [ ] Alert o soglie di spesa

---

### Fase E — Rilascio graduale

- [ ] Abilitare `realtime` su **una** simulazione pilota in produzione
- [ ] Monitorare 24–48h (errori, latenza, costi)
- [ ] Estendere a più simulazioni / utenti selezionati
- [ ] Documentare rollback: tornare a `aiProvider: "gpt"` su Firestore

---

## Riferimenti rapidi

| Cosa | Dove |
|------|------|
| Proxy Node | `ai-backend/` |
| Nginx snippet | `ai-backend/deploy/nginx-ai-creditcore.conf` |
| PM2 config | `ai-backend/ecosystem.config.cjs` |
| Preflight SSH | `ai-backend/deploy/server_preflight.sh` |
| Deploy dettagliato | `docs/roleplay_realtime_deploy.md` |
| QA scenari | `docs/roleplay_realtime_qa.md` |
| Flutter Realtime | `lib/services/roleplay_realtime_session.dart` |
| URL prod Flutter | `lib/config/roleplay_backend_config.dart` |

---

## Decisioni già prese (non rivalutare ora)

- **Nessun fallback automatico GPT** se Realtime è down → errore esplicito all'utente
- **`session.update` costruito in Flutter** — il proxy inoltra senza modificare il prompt
- **`hetzner` in Firestore** → normalizzato a `gpt` (solo compatibilità dati storici)
- **GPT invariato** — `roleplayStep` Firebase, STT/TTS locali

---

*Ultimo aggiornamento: roadmap post Fase 7 — deploy da PC di casa.*
