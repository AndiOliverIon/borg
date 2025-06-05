Clear-Host

# ╭────────────────────────────────────────────────────────╮
# │ 🛠️ SQL Server Docker Database Provision & Restore 🔄  │
# ╰────────────────────────────────────────────────────────╯
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkCyan
Write-Host "🛠️  SQL Server Docker Database Provision & Restore" -ForegroundColor Cyan
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkCyan
Write-Host ""

. "$env:BORG_ROOT\config\globalfn.ps1"

# 🔐 Switching to sql work folder while preserving the current location to switch back
$currentLocation = (Get-Location).Path
if (Test-Path $sqlBackupFolder) {
    Set-Location $sqlBackupFolder
}

# 🚀 Step 1: Create container
Write-Host ""
Write-Host "🚀 Step 1: Creating SQL Server $ContainerName container..." -ForegroundColor Cyan
& "$dockerFolder\clean.ps1"
& "$dockerFolder\sql-container.ps1"

# 📤 Step 2: Upload backup
Write-Host "📤 Step 2: Uploading backup file to container..." -ForegroundColor Cyan
$FileName = & "$dockerFolder\file-upload.ps1"

# 🕒 Step 3: Wait for SQL to be ready
Write-Host ""
Write-Host "🕒 Step 3: Waiting for SQL Server to initialize..." -ForegroundColor Cyan

$ready = $false
$timeout = 600
$startTime = Get-Date
$attempt = 1

while (-not $ready) {
    try {
        $logOutput = docker logs $ContainerName
        if ($logOutput -match "SQL Server is now ready for client connections") {
            Write-Host "✅ SQL Server in '$ContainerName' is ready." -ForegroundColor Green
            $ready = $true
        }
        else {
            Write-Host "⏳ Attempt $attempt - SQL not ready yet..." -ForegroundColor DarkYellow
            Start-Sleep -Seconds 1
            $attempt++
        }
    }
    catch {
        Write-Host "💥 Error while checking logs: $_" -ForegroundColor Red
        Start-Sleep -Seconds 5
    }

    $elapsed = (Get-Date) - $startTime
    if ($elapsed.TotalSeconds -ge $timeout) {
        Write-Host "❌ SQL Server failed to initialize within 10 minutes." -ForegroundColor Red
        exit 1
    }
}

Start-Sleep -Seconds 2

# 🧨 Step 4: Restore the database
Write-Host "🧨 Step 4: Restoring database from '$FileName'..." -ForegroundColor Cyan
& "$dockerFolder\sql-restore.ps1" $containerName $FileName

# 🔚 Restore working location
Set-Location $currentLocation

# 🏁 Completion banner
Write-Host "`n✅ All steps completed successfully!" -ForegroundColor Green
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkCyan
Write-Host "🏁 SQL Container & Restore Operation Finished" -ForegroundColor Cyan
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkCyan
