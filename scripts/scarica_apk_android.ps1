# Scarica APK CreditCalc per Android (installazione diretta via WhatsApp)
# Uso: powershell -ExecutionPolicy Bypass -File .\scripts\scarica_apk_android.ps1

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
    return "1.0.18"
}

$version = Get-AppVersion
$apkName = "CreditCalc-$version-android-arm64.apk"
$apkPath = Join-Path $dist $apkName

$existing = Get-ChildItem $dist -Filter "CreditCalc-*-android-arm64.apk" -ErrorAction SilentlyContinue |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 1

if ($existing) {
    if ($existing.FullName -ne $apkPath) {
        Copy-Item $existing.FullName $apkPath -Force
    }
    $sizeMb = [math]::Round($existing.Length / 1048576, 1)
    Write-Host "==> APK gia presente: $apkPath"
    Write-Host "    Dimensione: $sizeMb MB"
    $desktop = [Environment]::GetFolderPath("Desktop")
    $dest = Join-Path $desktop $apkName
    Copy-Item $apkPath $dest -Force
    Write-Host "==> Copiato sul Desktop: $dest"
    exit 0
}

if ($UsaLocale) {
    throw "Nessun APK in dist. Rimuovi -UsaLocale per scaricare da GitHub Actions."
}

Write-Host "==> Cerco build Android su GitHub Actions..."
$repo = "Marcellodinapoli/credit-calc-store"
$runs = Invoke-RestMethod -Uri "https://api.github.com/repos/$repo/actions/workflows/build-android.yml/runs?per_page=10&status=completed" -Headers @{ "User-Agent" = "CreditCalc-Download" }
$success = $runs.workflow_runs | Where-Object { $_.conclusion -eq "success" } | Select-Object -First 1
if (-not $success) { throw "Nessuna build Android riuscita trovata su GitHub." }

$sha = $success.head_sha.Substring(0, 7)
Write-Host "    Run #$($success.run_number) commit $sha"
$artifacts = Invoke-RestMethod -Uri $success.artifacts_url -Headers @{ "User-Agent" = "CreditCalc-Download" }
$artifact = $artifacts.artifacts | Where-Object { $_.name -eq "CreditCalc-Android" } | Select-Object -First 1
if (-not $artifact) { throw "Artifact CreditCalc-Android non trovato." }

if ([string]::IsNullOrWhiteSpace($GitHubToken)) {
    Write-Host ""
    Write-Host "Per scaricare automaticamente serve un token GitHub."
    Write-Host "In alternativa, scarica manualmente dal browser:"
    Write-Host $success.html_url
    Write-Host "Artifacts -> CreditCalc-Android -> scarica zip -> estrai APK in dist"
    Write-Host ""
    Write-Host "Oppure imposta GITHUB_TOKEN e rilancia lo script."
    exit 1
}

$zipTmp = Join-Path $dist "_github-android.zip"
$headers = @{
    "User-Agent" = "CreditCalc-Download"
    "Authorization" = "Bearer $GitHubToken"
    "Accept" = "application/vnd.github+json"
}
$sizeMb = [math]::Round($artifact.size_in_bytes / 1048576, 1)
Write-Host "==> Download artifact: $sizeMb MB"
Invoke-WebRequest -Uri $artifact.archive_download_url -OutFile $zipTmp -Headers $headers

$extractTmp = Join-Path $dist "_github-android-extract"
if (Test-Path $extractTmp) { Remove-Item $extractTmp -Recurse -Force }
Expand-Archive -Path $zipTmp -DestinationPath $extractTmp -Force
Remove-Item $zipTmp -Force

$found = Get-ChildItem $extractTmp -Recurse -Filter "*.apk" | Select-Object -First 1
if (-not $found) { throw "APK non trovato nell artifact scaricato." }

Copy-Item $found.FullName $apkPath -Force
Remove-Item $extractTmp -Recurse -Force -ErrorAction SilentlyContinue

$finalMb = [math]::Round((Get-Item $apkPath).Length / 1048576, 1)
Write-Host "==> APK pronto: $apkPath"
Write-Host "    Dimensione: $finalMb MB"

$desktop = [Environment]::GetFolderPath("Desktop")
$dest = Join-Path $desktop $apkName
Copy-Item $apkPath $dest -Force
Write-Host "==> Copiato sul Desktop: $dest"
Write-Host ""
Write-Host "Invia il file APK su WhatsApp e aprilo sul telefono per installare."
