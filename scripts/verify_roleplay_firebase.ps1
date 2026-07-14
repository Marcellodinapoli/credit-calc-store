# Verifica deploy Roleplay su Firebase (creditform-d505d)
# Uso: .\scripts\verify_roleplay_firebase.ps1

$ErrorActionPreference = "Stop"
$Project = "creditform-d505d"
$RequiredFunctions = @("roleplayStep", "roleplaySuggestion")
$RequiredRegion = "europe-west1"

Write-Host ""
Write-Host "=== Roleplay Firebase - $Project ===" -ForegroundColor Cyan

$RepoRoot = Split-Path $PSScriptRoot -Parent
Push-Location $RepoRoot

try {
    Write-Host ""
    Write-Host "[1/3] Cloud Functions deployate..." -ForegroundColor Yellow
    $listRaw = firebase functions:list --project $Project 2>&1 | Out-String
    if ($LASTEXITCODE -ne 0) {
        throw "firebase functions:list fallito"
    }

    $missing = @()
    foreach ($name in $RequiredFunctions) {
        if ($listRaw -notlike "*$name*") {
            $missing += $name
            Write-Host "  MANCANTE: $name" -ForegroundColor Red
        }
        elseif ($listRaw -like "*$name*$RequiredRegion*") {
            Write-Host "  OK: $name ($RequiredRegion)" -ForegroundColor Green
        }
        else {
            Write-Host "  ATTENZIONE: $name trovata, verifica regione manualmente" -ForegroundColor DarkYellow
        }
    }

    if ($listRaw -like "*roleplayGptStep*") {
        Write-Host "  ATTENZIONE: roleplayGptStep legacy presente" -ForegroundColor DarkYellow
    }

    Write-Host ""
    Write-Host "[2/3] Secret OPENAI_API_KEY..." -ForegroundColor Yellow
    firebase functions:secrets:access OPENAI_API_KEY --project $Project 2>&1 | Out-Null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  OK: secret configurato" -ForegroundColor Green
    }
    else {
        Write-Host "  MANCANTE - usa: firebase functions:secrets:set OPENAI_API_KEY --project $Project" -ForegroundColor Red
    }

    Write-Host ""
    Write-Host "[3/3] Firestore BackOffice (contenuti)..." -ForegroundColor Yellow
    Write-Host "  Collection roleplay: prompt, practiceData, category"
    Write-Host "  settings/plan_limits: monthlyRoleplay (opzionale)"

    Write-Host ""
    Write-Host "=== Aggiornare le function ===" -ForegroundColor Cyan
    Write-Host "  cd functions; npm run build"
    Write-Host "  firebase deploy --only functions:roleplayStep,functions:roleplaySuggestion --project $Project"

    if ($missing.Count -gt 0) {
        Write-Host ""
        Write-Host "ESITO: INCOMPLETO" -ForegroundColor Red
        exit 1
    }

    Write-Host ""
    Write-Host "ESITO: Functions OK. Prova simulazione su CreditPlanet." -ForegroundColor Green
    exit 0
}
finally {
    Pop-Location
}
