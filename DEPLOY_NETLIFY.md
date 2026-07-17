# Pubblicare CreditPlanet su Netlify

Siti: **https://creditplanet.netlify.app** (e eventuale preview/work)

Repository GitHub: **Marcellodinapoli/credit-calc-store** (branch `main`)

## Perché il deploy non parte o fallisce

1. **Netlify collegato al repo sbagliato** (es. vecchio `Creditplanet.git`) → riconnetti a `credit-calc-store`.
2. **GitHub Actions senza secrets** → [Actions](https://github.com/Marcellodinapoli/credit-calc-store/actions) rosso con "Secrets Netlify mancanti".
3. **Build Flutter fallita** → Netlify *Deploys* → ultimo deploy → *Deploy log*.
4. **Cache browser** → Flutter web usa service worker: **Ctrl+Shift+R** o cancella dati sito.
5. **Plugin Flutter obsoleto** → questo repo usa `scripts/netlify_build.sh`, non plugin esterni.

## Opzione A — Netlify collegato a GitHub (build su Netlify)

In [Netlify](https://app.netlify.com) → sito **creditplanet** → **Site configuration** → **Build & deploy**:

| Impostazione | Valore |
|--------------|--------|
| Repository | `Marcellodinapoli/credit-calc-store` |
| Branch | `main` |
| Build command | *(vuoto — legge `netlify.toml`)* |
| Publish directory | `build/web` |

Poi **Trigger deploy** → **Deploy site**.

Il file `netlify.toml` esegue `bash scripts/netlify_build.sh` (installa Flutter se serve).

## Opzione B — GitHub Actions (consigliata)

GitHub → [Settings → Secrets → Actions](https://github.com/Marcellodinapoli/credit-calc-store/settings/secrets/actions)

### B1 — Build hook (1 secret, più semplice)

1. Netlify → **creditplanet** → **Build & deploy** → **Build hooks** → **Add build hook** (branch `main`)
2. Copia l’URL → secret GitHub `NETLIFY_BUILD_HOOK`
3. Push su `main` oppure **Actions** → **Deploy Web to Netlify** → **Run workflow**

Netlify esegue il build usando `netlify.toml`.

### B2 — Token + Site ID (2 secrets)

1. `NETLIFY_AUTH_TOKEN` — Netlify → User settings → Applications → New access token
2. `NETLIFY_SITE_ID` — creditplanet → Site details → **API ID** (non il nome sito)

GitHub builda Flutter e carica `build/web` via API Netlify.

## Opzione C — Deploy manuale da Windows

```powershell
cd "C:\Users\271\Desktop\Marcello\Esiti test\creditplanet"
powershell -ExecutionPolicy Bypass -File .\scripts\netlify_build.ps1
npx netlify-cli deploy --prod --dir=build\web
```

Prima volta: `npx netlify-cli login`

Oppure tutto in uno:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\deploy_netlify_local.ps1
```

## Verifica rapida

- Push su `main` → workflow verde in GitHub Actions
- Netlify → Deploys → ultimo deploy **Published**
- Sito aggiornato dopo 1–2 minuti (hard refresh se serve)
