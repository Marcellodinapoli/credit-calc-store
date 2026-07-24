# Deploy Cloud Functions AI usage + verifica costi.
# Esegui in PowerShell DOPO: firebase login
#
# Uso:
#   .\scripts\deploy-and-verify-ai-usage.ps1
#   $env:OPENAI_API_KEY="sk-..."; .\scripts\deploy-and-verify-ai-usage.ps1 -Live

param(
  [switch]$Live
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

Write-Host "==> Build functions" -ForegroundColor Cyan
Push-Location functions
npm run build
if ($LASTEXITCODE -ne 0) { throw "build failed" }

Write-Host "==> Verifica costi (offline)" -ForegroundColor Cyan
node scripts/verify_ai_usage_costs.cjs
if ($LASTEXITCODE -ne 0) { throw "offline verify failed" }

if ($Live -or $env:OPENAI_API_KEY) {
  Write-Host "==> Verifica live OpenAI" -ForegroundColor Cyan
  node scripts/verify_ai_usage_costs.cjs --live
  if ($LASTEXITCODE -ne 0) { throw "live verify failed" }
}

Write-Host "==> Deploy functions (creditform-d505d)" -ForegroundColor Cyan
firebase deploy --only `
  "functions:trackRoleplayRealtimeUsage,functions:warmupEvaluate,functions:normativeSearch,functions:callAnalysis,functions:roleplayStep,functions:roleplaySuggestion,functions:contestationGenerate,functions:getAiUsageStats,functions:roleplayRealtimeToken" `
  --project creditform-d505d

if ($LASTEXITCODE -ne 0) { throw "deploy failed" }

Write-Host "Deploy OK. Verifica Realtime dall'app: una sessione roleplay deve scrivere ai_usage con feature=roleplayRealtime." -ForegroundColor Green
Pop-Location
