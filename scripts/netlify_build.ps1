# Build Flutter Web in locale (Windows).
# Uso: powershell -ExecutionPolicy Bypass -File .\scripts\netlify_build.ps1

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
Push-Location $root

Write-Host "==> flutter pub get"
flutter pub get

if (Test-Path "packages\credit_calc_core") {
  Push-Location "packages\credit_calc_core"
  flutter pub get
  Pop-Location
}

if (-not (Test-Path "web\index.html")) {
  flutter create --platforms=web .
}

Write-Host "==> flutter build web --release"
flutter build web --release

if (-not (Test-Path "build\web\index.html")) {
  throw "Build fallita: manca build\web\index.html"
}

Write-Host "==> Build OK: $root\build\web"
Pop-Location
