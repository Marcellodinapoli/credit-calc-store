# Roleplay Realtime — architettura attuale

## Flusso produzione (obbligatorio)

```
Flutter (Android)
  → Firebase Callable `roleplayRealtimeToken`
  → OpenAI client secret (ephemeral), API key solo sul server
  → WebSocket diretto `wss://api.openai.com/v1/realtime`
  → audio bidirezionale (microfono / riproduzione)
```

- **Niente** proxy Fly / VPS / Nginx per Realtime.
- **Niente** `roleplayStep` durante la chiamata vocale.
- Factory: sempre `RoleplayRealtimeSession`.

## Endpoint vietati (non usare)

- `creditcore-realtime.fly.dev`
- `ai.creditcore.it/realtime-ws`
- qualsiasi host `*/realtime-ws` legacy

## Deploy Function

```bash
cd functions
npm run build
npx firebase deploy --only functions:roleplayRealtimeToken --project creditform-d505d
```

## Test

Solo app Android sul telefono (non Chrome/Web):

```bash
flutter clean
flutter pub get
adb uninstall com.creditcore.creditcalc
flutter run -d <deviceId>
```
