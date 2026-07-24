# Procedura rilascio monitoraggio Consumi AI

Documento operativo per deploy e verifica end-to-end del tracking OpenAI in CreditCalc Store.

## Quando usarla

Dopo modifiche a:

- `functions/src/ai_usage_tracker.ts`
- callable AI (`roleplay*`, `warmupEvaluate`, `normativeSearch`, `callAnalysis`, …)
- tracking Realtime client (`roleplay_realtime_session.dart`)
- card Consumi AI / `AiUsageAdminService`

## Sequenza obbligatoria

1. **`firebase login`**  
   Sul PC con browser. **Non** usare `firebase login:ci` (solo se stai configurando CI/CD).

2. **Deploy Cloud Functions** (`creditform-d505d`)

   ```powershell
   cd functions
   npm run build
   firebase deploy --only functions:trackRoleplayRealtimeUsage,functions:warmupEvaluate,functions:normativeSearch,functions:callAnalysis,functions:roleplayStep,functions:roleplaySuggestion,functions:contestationGenerate,functions:getAiUsageStats,functions:roleplayRealtimeToken --project creditform-d505d
   ```

   Oppure: `.\scripts\deploy-and-verify-ai-usage.ps1`

3. **Test reale sull’app** (non solo lo script)

   - 1 Roleplay Realtime  
   - 1 `roleplaySuggestion`  
   - 1 Warm-up (`warmupEvaluate`)  
   - 1 Ricerca normativa  

4. **Controlli Firestore + UI**

   - Collection `ai_usage` → nuovi documenti per le feature usate  
   - `settings/ai_usage/months/{YYYY-MM}` → `totals` / `features.*` incrementati  
   - Card **Utilizzo AI del mese** (Consumi AI) in app → stessi incrementi  

5. **Confronta OpenAI Usage**

   Stesso intervallo temporale e progetto.  
   Token: devono coincidere.  
   Costi: tollera piccole differenze di arrotondamento.

6. **Solo a questo punto**

   - Commit  
   - Release app (Windows + Android)

## Catena validata

```
OpenAI → Cloud Function → Firestore → UI app
```

## Script di supporto (non sostitutivi)

| Script | Ruolo |
|--------|--------|
| `functions/scripts/verify_ai_usage_costs.cjs` | Verifica listino / formula costi offline (+ `--live` se `OPENAI_API_KEY`) |
| `scripts/deploy-and-verify-ai-usage.ps1` | Build + verify offline + deploy |

## Feature trackate

| Feature | Origine |
|---------|---------|
| `roleplayRealtime` | Sessioni vocale Realtime (`response.done`) |
| `roleplaySuggestion` | Suggerimento post-chiamata |
| `roleplayStep` | Turni Chat (legacy / non UI attuale) |
| `warmupEvaluate` | Warm-up + Whisper |
| `contestationGenerate` | Contestazioni |
| `normativeSearch` | Ricerca normativa |
| `callAnalysis` | Analisi telefonata |
