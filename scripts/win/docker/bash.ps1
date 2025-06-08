param(
    [Parameter(ValueFromPipeline = $true, Position = 0)]
    [string]$ContainerName
)

Clear-Host

# ╭────────────────────────────────────────────────────────╮
# │ 🚪 Entering SQL Docker Container — Backup Terminal 🧰 │
# ╰────────────────────────────────────────────────────────╯
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkCyan
Write-Host "🚪  Entering SQL Docker Container — Backup Terminal 🧰" -ForegroundColor Cyan
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkCyan
Write-Host ""

. "$env:BORG_ROOT\config\globalfn.ps1"

# 🧠 Resolve container
if (-not $ContainerName) {
    Write-Host "📦 No container specified — using default from credentials..." -ForegroundColor Yellow
    $container = $dockerContainer
}
else {
    Write-Host "📦 Container specified: $ContainerName"
    $container = $ContainerName
}

# 💬 Confirm Docker context
Write-Host "`n🔧 Connecting to container: '$container'" -ForegroundColor Cyan
Start-Sleep -Milliseconds 300

# 🚀 Open interactive shell to mssql backups
docker exec -it $container bash -c "cd $dockerBackupPath && exec bash"