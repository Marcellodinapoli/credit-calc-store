# Fase 6 — Collaudo Realtime (QA + produzione)

Vedi anche: [Deploy Fase 7](roleplay_realtime_deploy.md)

## Decisione fallback

**`aiProvider = realtime` con backend spento → errore controllato (SnackBar), nessun fallback automatico a GPT.**

Motivo: evita cambi silenziosi di motore, costi e comportamento. GPT resta il percorso esplicito per simulazioni `gpt`, alias legacy `hetzner`, o senza provider.

---

## 1. Test funzionale

### Provider GPT

| Scenario | Atteso | Verifica |
|----------|--------|----------|
| `aiProvider` assente | `RoleplayGptSession` | `flutter test test/roleplay_ai_provider_test.dart` |
| `aiProvider = gpt` | GPT | idem |
| alias legacy `hetzner` | normalizzato → GPT | idem |
| Comportamento | STT → `roleplayStep` → TTS | test manuale su simulazione esistente |

### Provider Realtime

| Step | Atteso |
|------|--------|
| `aiProvider = realtime` | `RoleplayRealtimeSession` via factory |
| Apertura simulazione | banner chiamata, stato `connecting` → `listening` |
| WebSocket | `wss://ai.creditcore.it/realtime-ws` (dev locale: `ws://127.0.0.1:3002` su web HTTP) |
| Bootstrap | `session.bootstrap` + `proxy.ready` |
| Microfono | stream PCM16 verso proxy |
| Risposta vocale | `response.audio.delta` + playback |
| Interrupt | `input_audio_buffer.speech_started` → `response.cancel` |
| Chiusura pagina | `stop()` + `dispose()` + mic/audio fermati |

### Fallback backend spento

| Atteso |
|--------|
| SnackBar: *Servizio Realtime non disponibile…* |
| Nessun passaggio a GPT |
| Simulazione non resta bloccata in stato attivo |

---

## 2. Test prestazioni Realtime

### Metriche (solo `kDebugMode`)

Log prefisso `RoleplayRealtime QA:` in console:

| Metrica | Evento |
|---------|--------|
| Click → sessione pronta | `start simulazione` → `proxy.ready` |
| Fine frase → audio | `speech_stopped` → `audio dopo turno N` |
| Prima risposta | `prima risposta audio` |

### Obiettivi

| Metrica | Target |
|---------|--------|
| Apertura → prima risposta | < 2 s |
| Turno successivo | < 1 s |
| Stabilità 10 min | nessun leak sessione, heartbeat attivo |

### Test manuale consigliato

1. Avviare backend: `cd ai-backend && npm start`
2. Smoke test: `cd ai-backend && npm run smoke`
3. App in debug su web (audio ottimale) o Windows
4. Simulazione Firestore con `aiProvider: "realtime"`
5. Registrare i log `RoleplayRealtime QA:`

---

## 3. Checklist produzione

```
Flutter
  ↓ WSS
ai.creditcore.it/realtime-ws
  ↓
Nginx / reverse proxy
  ↓
ai-backend (:3002 WS, :3000 /health)
  ↓
OpenAI Realtime API
```

| Controllo | Come |
|-----------|------|
| HTTPS/WSS | `curl https://ai.creditcore.it/health` |
| Nginx WebSocket | `deploy/nginx-ai-creditcore.conf` |
| PM2 restart | `pm2 start ecosystem.config.cjs` + `pm2 save` |
| Log senza API key | `pm2 logs` — mai `sk-` in chiaro |
| Smoke | `npm run smoke -- https://ai.creditcore.it wss://ai.creditcore.it/realtime-ws` |

---

## 4. Audio native (non in questa fase)

Web: Web Audio API (ottimale).  
Native: WAV chunk + audioplayers (compromesso accettato per collaudo).

---

## 5. Sicurezza e costi (pre-rilascio)

| Requisito | Stato |
|-----------|-------|
| Firebase UID su bootstrap | Implementato |
| Chiusura sessioni inattive | Implementato |
| Rate limit per utente | Da implementare |
| Max minuti Realtime/giorno | Da implementare |
| Log utilizzo/costi | Da implementare |

---

## 6. Migrazione graduale

| Piano | Provider |
|-------|----------|
| Free | GPT |
| Plus | Realtime (limite giornaliero) |
| Azienda | Realtime |

---

## Comandi rapidi

```bash
flutter test test/roleplay_ai_provider_test.dart
flutter test test/roleplay_session_factory_test.dart
flutter test test/roleplay_realtime_session_config_test.dart

cd ai-backend && npm start
cd ai-backend && npm run smoke
cd ai-backend && npm run smoke -- https://ai.creditcore.it wss://ai.creditcore.it/realtime-ws
```
