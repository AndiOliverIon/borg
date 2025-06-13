# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 🚀 Safe Publisher for BORG — with credential stripping
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

. "$env:BORG_ROOT\config\globalfn.ps1"

$ErrorActionPreference = 'Stop'

# 🔑 Get API Key from first argument
$apiKey = $args[0]
if (-not $apiKey) {
    Write-Host "❌ Please provide the NuGet API key as the first argument." -ForegroundColor Red
    Write-Host "💡 Example: .\publish.ps1 <Your-API-Key>" -ForegroundColor DarkYellow
    exit 1
}

Write-Host "🚀 Publishing BORG module..." -ForegroundColor Green
Publish-Module -Path $borgRoot -NuGetApiKey $apiKey

Write-Host "`n🎉 BORG module published safely!" -ForegroundColor Cyan
