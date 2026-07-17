# Build web in locale e pubblica su Netlify.
# Prerequisito: npm install -g netlify-cli   oppure   npx netlify-cli
#
# Uso:
#   powershell -ExecutionPolicy Bypass -File .\scripts\deploy_netlify_local.ps1
#
# Prima volta: netlify login

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
Push-Location $root

& "$PSScriptRoot\netlify_build.ps1"

Write-Host "==> netlify deploy --prod"
netlify deploy --prod --dir=build\web

Pop-Location
