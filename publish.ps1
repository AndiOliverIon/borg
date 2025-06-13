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

# 💼 Paths
$configFolder = Join-Path $env:BORG_ROOT 'data'
$storePath = Join-Path $configFolder 'store.json'
$tempPath = 'C:\temp\store.json'

# 🛡️ Step 1: Backup store.json
if (Test-Path $storePath) {
    Copy-Item -Path $storePath -Destination $tempPath -Force
    Write-Host "📁 store.json backed up to $tempPath" -ForegroundColor Yellow
}

# 🧹 Step 2: Remove store.json from repo
if (Test-Path $storePath) {
    Remove-Item -Path $storePath -Force
    Write-Host "🧹 store.json removed from $configFolder" -ForegroundColor Cyan
}

# 📤 Step 3: Publish BORG module
Write-Host "🚀 Publishing BORG module..." -ForegroundColor Green
Publish-Module -Path $borgRoot -NuGetApiKey $apiKey

# ♻️ Step 4: Restore store.json
if (Test-Path $tempPath) {
    Copy-Item -Path $tempPath -Destination $storePath -Force
    Write-Host "✅ store.json restored to $storePath" -ForegroundColor Green
}

# 🗑️ Step 5: Cleanup
if (Test-Path $tempPath) {
    Remove-Item -Path $tempPath -Force
    Write-Host "🗑️ Temporary store.json removed from $tempPath" -ForegroundColor DarkGray
}

Write-Host "`n🎉 BORG module published safely!" -ForegroundColor Cyan
