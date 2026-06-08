# CreditCalc Store

App ufficiale CreditCore per **Google Play**, **App Store**, **Microsoft Store** e **Mac App Store**.

## Dipendenze

- **[credit-calc-core](https://github.com/Marcellodinapoli/credit-calc-core)** — libreria condivisa con CreditPlanet (unica fonte Git).

## Sviluppo

```bash
flutter pub get
flutter run
```

## Build Windows (exe + installer)

Versione attuale: **1.0.6**

Output fisso (come `creditcalc-tool`):

```
dist/CreditCalc-1.0.6-win64/CreditCalc.exe
dist/CreditCalc-1.0.6-Setup.exe
```

Per compilarlo (richiede **Inno Setup 6**):

```powershell
.\scripts\build_windows_release.ps1
```

Oppure doppio click su `scripts\build_windows_release.bat`.
