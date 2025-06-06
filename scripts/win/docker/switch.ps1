# ╭──────────────────────────────────────────────╮
# │ 🧠  SQL Docker Jump between snapshots initiated     │
# ╰──────────────────────────────────────────────╯
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkCyan
Write-Host "🧠  SQL Docker Jump between snapshots Initiated" -ForegroundColor Cyan
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkCyan
Write-Host ""

. "$env:BORG_ROOT\config\globalfn.ps1"

try {
    $backupListCommand = "ls -1 $dockerBackupPath/*.bak"
    $backupList = docker exec $ContainerName bash -c $backupListCommand

    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ Failed to retrieve backup list: $backupList" -ForegroundColor Red
        return
    }

    $backupFiles = $backupList -split "`n" | Where-Object { $_ -ne '' }

    if ($backupFiles.Count -eq 0) {
        Write-Host "🚫 No backups found in container." -ForegroundColor Red
        return
    }

    Write-Host "`n📋 Available backups in container:" -ForegroundColor Green
    $backupFiles | ForEach-Object {
        $fileName = Split-Path $_ -Leaf
        Write-Host "📁 $fileName"
    }

    Write-Host "`n🔎 Select a backup using fzf..." -ForegroundColor Yellow
    $selectedFile = $backupFiles | ForEach-Object { Split-Path $_ -Leaf } | fzf --height 40%

    if (-not $selectedFile) {
        Write-Host "❌ No selection made. Exiting." -ForegroundColor Red
        return
    }

    $BackupFile = $selectedFile
    $proposed = $BackupFile -split '_' | Select-Object -First 1
}
catch {
    Write-Host "💥 Error retrieving backup list. Details: $_" -ForegroundColor Red
    return
}

# 🧩 Composite backup handling
if ($BackupFile -match '_') {
    $baseBackupFile = ($BackupFile -split '_')[0] + ".bak"
    $backupFilePath = "$dockerBackupPath/$baseBackupFile"
    $compositeBackupFilePath = "$dockerBackupPath/$BackupFile"

    Write-Host "`n🔄 Detected composite backup: '$BackupFile'" -ForegroundColor Cyan
    try {
        Write-Host "🧹 Removing existing base backup (if any): $baseBackupFile" -ForegroundColor Gray
        $deleteCommand = "if [ -f '$backupFilePath' ]; then rm '$backupFilePath'; fi"
        docker exec $ContainerName bash -c $deleteCommand

        Write-Host "📎 Copying ➜ '$BackupFile' → '$baseBackupFile'" -ForegroundColor Cyan
        $copyCommand = "cp '$compositeBackupFilePath' '$backupFilePath'"
        docker exec $ContainerName bash -c $copyCommand

        $BackupFile = $baseBackupFile
    }
    catch {
        Write-Host "❌ Composite handling failed. $_" -ForegroundColor Red
        return
    }
}

# 🎯 Confirmation
Write-Host "`n🎯 Selected backup file: '$BackupFile'" -ForegroundColor Green
Write-Host "🛠️ Starting restore in container: '$ContainerName'" -ForegroundColor Cyan

# 🚀 Execute restore
try {
    $executeCommand = "$dockerBackupPath/restore_database.sh '$BackupFile' '$SqlPassword' '$proposed'"
    Write-Host "`n🚀 Executing restore command:" -ForegroundColor Yellow
    Write-Host "   $executeCommand" -ForegroundColor DarkGray
    Write-Host "🔧 Running script inside container..." -ForegroundColor Yellow

    $executionResult = docker exec $ContainerName bash -c $executeCommand

    if ($LASTEXITCODE -ne 0) {
        Write-Host "`n❌ Restore script failed:" -ForegroundColor Red
        Write-Host $executionResult
        return
    }

    # 💬 Output from restore
    Write-Host "`n📤 Output:" -ForegroundColor Gray
    Write-Host "──────────────────────────────────────────────" -ForegroundColor DarkGray
    Write-Host $executionResult
    Write-Host "──────────────────────────────────────────────" -ForegroundColor DarkGray

    Write-Host "`n✅ Restore completed successfully!" -ForegroundColor Green
}
catch {
    Write-Host "💥 Unexpected error during execution: $_" -ForegroundColor Red
}

# 🏁 Done
Write-Host "`n🏁 SQL Restore Flow Complete" -ForegroundColor Cyan
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkCyan
