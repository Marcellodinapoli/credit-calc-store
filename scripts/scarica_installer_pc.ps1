# Scarica l'installer CreditCalc per PC SENZA avere Flutter installato.
# Uso:
#   powershell -ExecutionPolicy Bypass -File .\scripts\scarica_installer_pc.ps1
#
# Opzioni:
#   -UsaLocale     Usa solo dist\ se già presente (default: prova locale, poi GitHub)
#   -GitHubToken   Token GitHub per scaricare l'artifact Actions (opzionale)

param(
    [switch]$UsaLocale,
    [string]$GitHubToken = $env:GITHUB_TOKEN
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$dist = Join-Path $root "dist"
New-Item -ItemType Directory -Force -Path $dist | Out-Null

function Get-AppVersion {
    $pubspec = Join-Path $root "pubspec.yaml"
    $line = Get-Content $pubspec | Where-Object { $_ -match '^\s*version:\s*' } | Select-Object -First 1
    if ($line -match 'version:\s*(\d+\.\d+\.\d+)') { return $Matches[1] }
    return "1.0.13"
}

$version = Get-AppVersion
$setupName = "CreditCalc-$version-Setup.exe"
$setupPath = Join-Path $dist $setupName
$portableDir = Join-Path $dist "CreditCalc-$version-win64"
$zipPath = Join-Path $dist "CreditCalc-$version-win64.zip"

if ((Test-Path $setupPath) -or (Test-Path (Join-Path $portableDir "CreditCalc.exe"))) {
    Write-Host "==> File gia presenti in dist (versione $version)"
    if (Test-Path $setupPath) { Write-Host "    Installer: $setupPath" }
    if (Test-Path (Join-Path $portableDir "CreditCalc.exe")) {
        Write-Host "    Portable:  $portableDir\CreditCalc.exe"
    }
    if (-not $UsaLocale) {
        $desktop = [Environment]::GetFolderPath("Desktop")
        if (Test-Path $setupPath) {
            $dest = Join-Path $desktop $setupName
            Copy-Item $setupPath $dest -Force
            Write-Host "==> Copiato sul Desktop: $dest"
        }
    }
    exit 0
}

if ($UsaLocale) {
    throw "Nessun installer in dist. Rimuovi -UsaLocale per scaricare da GitHub Actions."
}

Write-Host "==> Cerco build Windows su GitHub Actions..."
$repo = "Marcellodinapoli/credit-calc-store"
$runs = Invoke-RestMethod -Uri "https://api.github.com/repos/$repo/actions/workflows/build-windows.yml/runs?per_page=5&status=completed" -Headers @{ "User-Agent" = "CreditCalc-Download" }
$success = $runs.workflow_runs | Where-Object { $_.conclusion -eq "success" } | Select-Object -First 1
if (-not $success) { throw "Nessuna build Windows riuscita trovata su GitHub." }

Write-Host "    Run #$($success.run_number) — $($success.head_sha.Substring(0,7))"
$artifacts = Invoke-RestMethod -Uri $success.artifacts_url -Headers @{ "User-Agent" = "CreditCalc-Download" }
$artifact = $artifacts.artifacts | Where-Object { $_.name -eq "CreditCalc-Windows" } | Select-Object -First 1
if (-not $artifact) { throw "Artifact CreditCalc-Windows non trovato." }

if ([string]::IsNullOrWhiteSpace($GitHubToken)) {
    Write-Host ""
    Write-Host "Per scaricare automaticamente serve un token GitHub (repo pubblico)."
    Write-Host "In alternativa, scarica manualmente:"
    Write-Host "  $($success.html_url)"
    Write-Host "  -> Artifacts -> CreditCalc-Windows"
    Write-Host ""
    Write-Host "Oppure imposta GITHUB_TOKEN e rilancia lo script."
    exit 1
}

$zipTmp = Join-Path $dist "_github-artifact.zip"
$headers = @{
    "User-Agent" = "CreditCalc-Download"
    "Authorization" = "Bearer $GitHubToken"
    "Accept" = "application/vnd.github+json"
}
Write-Host "==> Download artifact..."
Invoke-WebRequest -Uri $artifact.archive_download_url -OutFile $zipTmp -Headers $headers

$extractTmp = Join-Path $dist "_github-extract"
if (Test-Path $extractTmp) { Remove-Item $extractTmp -Recurse -Force }
Expand-Archive -Path $zipTmp -DestinationPath $extractTmp -Force
Remove-Item $zipTmp -Force

Get-ChildItem $extractTmp -Recurse -Filter "*-Setup.exe" | ForEach-Object {
    Copy-Item $_.FullName $setupPath -Force
    Write-Host "==> Installer: $setupPath"
}
Get-ChildItem $extractTmp -Recurse -Directory -Filter "*-win64" | ForEach-Object {
    if (Test-Path $portableDir) { Remove-Item $portableDir -Recurse -Force }
    Copy-Item $_.FullName $portableDir -Recurse -Force
    Write-Host "==> Portable: $portableDir"
}
Remove-Item $extractTmp -Recurse -Force -ErrorAction SilentlyContinue

if (-not (Test-Path $setupPath)) {
    throw 'Download completato ma Setup.exe non trovato nell''artifact.'
}

$readme = @(
    "FILE DA DISTRIBUIRE (versione $version)"
    "======================================"
    ""
    "  $setupPath"
    ""
    "Portable (senza installer):"
    "  $portableDir\CreditCalc.exe"
    ""
    "Scaricato da GitHub Actions run $($success.id)"
)
Set-Content -Path (Join-Path $dist "LEGGIMI-DISTRIBUZIONE.txt") -Value $readme -Encoding UTF8

Write-Host ""
Write-Host "Fatto. Doppio click su dist\INSTALLA-CREDITCALC.bat per installare."
