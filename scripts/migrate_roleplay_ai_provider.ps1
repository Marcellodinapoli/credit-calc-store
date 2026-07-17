# Migra tutte le simulazioni roleplay a aiProvider = "realtime"
# Uso:
#   .\scripts\migrate_roleplay_ai_provider.ps1 -DryRun
#   .\scripts\migrate_roleplay_ai_provider.ps1

param(
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"
$RepoRoot = Split-Path $PSScriptRoot -Parent
Push-Location $RepoRoot

try {
    $functionsNode = Join-Path $RepoRoot "functions\node_modules\firebase-admin"
    if (-not (Test-Path $functionsNode)) {
        Write-Host "Installazione dipendenze functions..." -ForegroundColor Yellow
        Push-Location (Join-Path $RepoRoot "functions")
        npm ci --omit=dev 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) { throw "npm ci in functions/ fallito" }
        Pop-Location
    }

    $args = @("scripts/migrate_roleplay_ai_provider.mjs")
    if ($DryRun) { $args += "--dry-run" }

    Write-Host ""
    Write-Host "=== Migrazione Firestore roleplay → realtime ===" -ForegroundColor Cyan
    if ($DryRun) {
        Write-Host "Anteprima (nessuna modifica)" -ForegroundColor DarkYellow
    }
    Write-Host ""

    node @args
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

    if (-not $DryRun) {
        Write-Host ""
        Write-Host "Verifica: apri BackOffice Roleplay e controlla Motore AI = OpenAI Realtime." -ForegroundColor Green
    }
}
finally {
    Pop-Location
}
