Clear-Host

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 📥 SQL Docker File/Folder Downloader — Interactive Mode
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

. "$env:BORG_ROOT\config\globalfn.ps1"

$HostPath = Get-Location

Write-Host "`n📡 Querying container '$ContainerName' for contents of '$dockerBackupPath'..." -ForegroundColor Cyan

# 🧾 List all items in backup folder
try {
    $entries = docker exec "$ContainerName" ls -1 "$dockerBackupPath"

    if (-not $entries) {
        Write-Host "❌ No files or folders found in '$dockerBackupPath'." -ForegroundColor Yellow
        exit 1
    }

    # 📋 Format entries with icons
    $displayToEntry = @{}
    $displayList = @()

    foreach ($entry in $entries) {
        $icon = switch -Wildcard ($entry) {
            "*.bak" { "🗃️" }
            "*.bacpac" { "🧱" }
            "*.zip" { "📦" }
            "*.mdf" { "🧬" }
            "*.ldf" { "📄" }
            default { "📁" }
        }

        $display = "$icon $entry"
        $displayList += $display
        $displayToEntry[$display] = $entry
    }

    $selectedDisplay = $displayList | fzf --ansi --prompt "📥 Select an item to download: " --height 40% --reverse | ForEach-Object { $_.Trim() }

    if (-not $selectedDisplay) {
        Write-Host "❌ No selection made. Aborting." -ForegroundColor Red
        exit 1
    }

    # 🧼 Strip emoji prefix to get the actual entry name
    $selectedItem = $selectedDisplay -replace '^[^\s]+\s+', ''
    $sourcePath = "$dockerBackupPath/$selectedItem"
    $destinationPath = Join-Path $HostPath $selectedItem

    Write-Host "`n⬇️  Downloading '$selectedItem' from container..." -ForegroundColor Cyan
    docker cp "${ContainerName}:$sourcePath" "$destinationPath"

    if (Test-Path $destinationPath) {
        Write-Host "✅ Downloaded to: '$destinationPath'" -ForegroundColor Green
    }
    else {
        Write-Host "⚠️  docker cp reported success, but destination not found: '$destinationPath'" -ForegroundColor Yellow
    }

    Write-Host "`n🏁 Done." -ForegroundColor Cyan
}
catch {
    Write-Host "❌ Error retrieving files from container. $_" -ForegroundColor Red
}
