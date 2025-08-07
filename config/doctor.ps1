Clear-Host

$separator = "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
Write-Host $separator -ForegroundColor Cyan
Write-Host "🩺  BORG Doctor — System Environment Checkup" -ForegroundColor Cyan
Write-Host $separator -ForegroundColor Cyan
Write-Host ""

function Check-Tool {
    param (
        [string]$ToolName,
        [bool]$IsMandatory = $true
    )

    $exists = Get-Command $ToolName -ErrorAction SilentlyContinue
    if ($exists) {
        Write-Host "  $ToolName found" -ForegroundColor Green
        return $true
    }
    else {
        $msg = "  $ToolName not found"
        if ($IsMandatory) {
            Write-Host $msg -ForegroundColor Red
        }
        else {
            Write-Host $msg -ForegroundColor DarkYellow
        }
        return $false
    }
}

#   Check PowerShell version
$pver = $PSVersionTable.PSVersion
$requiredMajor = 7
$requiredMinor = 5

Write-Host "  PowerShell version detected: $pver"
if ($pver.Major -gt $requiredMajor -or ($pver.Major -eq $requiredMajor -and $pver.Minor -ge $requiredMinor)) {
    Write-Host "  PowerShell version is compatible (≥ 7.5)" -ForegroundColor Green
}
else {
    Write-Host "  PowerShell 7.5 or newer is required. Current: $pver" -ForegroundColor Red
}

Write-Host ""
Write-Host "  Mandatory Tools:" -ForegroundColor White
Check-Tool -ToolName "fzf"
Check-Tool -ToolName "sqlcmd"
Check-Tool -ToolName "docker"

#   Check store.json readability
Write-Host "`n  Checking config: store.json"
if (Test-Path $storePath) {
    try {
        $null = Get-Content $storePath -Raw | ConvertFrom-Json
        Write-Host "  store.json is present and readable" -ForegroundColor Green
    }
    catch {
        Write-Host "  store.json is present but contains invalid JSON" -ForegroundColor Red
    }
}
else {
    Write-Host "  store.json is missing from: $storePath" -ForegroundColor Red
}

Write-Host "`n  Optional Tools:" -ForegroundColor White
Check-Tool -ToolName "micro" -IsMandatory:$false

Write-Host "`n$separator" -ForegroundColor Cyan
Write-Host "  Doctor check complete. Review above results." -ForegroundColor Cyan
Write-Host $separator -ForegroundColor Cyan


# --- Check for old versions ---
Write-Host "`n  Checking for installed Borg versions..."

$borgModulePath = Join-Path $env:USERPROFILE "Documents\PowerShell\Modules\Borg"
if (Test-Path $borgModulePath) {
    $versions = Get-ChildItem -Path $borgModulePath -Directory | Sort-Object Name
    if ($versions.Count -le 1) {
        Write-Host "  Only one version found. No cleanup needed." -ForegroundColor Green
    }
    else {
        Write-Host "  Installed versions:" -ForegroundColor Yellow
        foreach ($v in $versions) {
            Write-Host "    - $($v.Name)"
        }

        $currentScriptPath = $MyInvocation.MyCommand.Path
        $currentVersion = Split-Path -Parent $currentScriptPath | Split-Path -Leaf

        Write-Host "`n  Current version in use: $currentVersion"

        $toDelete = $versions | Where-Object { $_.Name -ne $currentVersion }
        Write-Host "  Older versions that can be removed:"
        foreach ($v in $toDelete) {
            Write-Host "    - $($v.Name)" -ForegroundColor DarkGray
        }

        $choice = Read-Host "`n  Do you want to remove older versions? (y/n)"
        if ($choice -eq 'y') {
            foreach ($v in $toDelete) {
                try {
                    Remove-Item -Recurse -Force -Path $v.FullName
                    Write-Host "  Removed: $($v.Name)" -ForegroundColor Green
                }
                catch {
                    Write-Host "  Failed to remove $($v.Name): $($_.Exception.Message)" -ForegroundColor Red
                }
            }
        }
        else {
            Write-Host "  Skipped cleanup." -ForegroundColor DarkYellow
        }
    }
}
else {
    Write-Host "  Borg module folder not found at: $borgModulePath" -ForegroundColor Red
}
