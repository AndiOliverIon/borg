#   BORG Network — wifi.ps1
param([string[]]$inputArgs)

. "$env:BORG_ROOT\config\globalfn.ps1"

# 🔍 DEBUG: Show received arguments
Write-Host "[debug] inputArgs: $($inputArgs -join ' ')" -ForegroundColor DarkGray

function Get-CurrentSSID {
    netsh wlan show interfaces |
    Where-Object { $_ -match '^\s*SSID\s+:' } |
    ForEach-Object { ($_ -split ':')[1].Trim() }
}

function IsYes($input) {
    $str = "$input"
    return ($str -eq '' -or $str.ToLower() -eq 'y')
}

# 🟢 If a single argument is provided, treat it as target SSID
if ($inputArgs.Count -eq 1) {
    $targetSSID = $inputArgs[0]
    Write-Host "[debug] Auto-connect mode for SSID: $targetSSID" -ForegroundColor DarkGray

    $current = Get-CurrentSSID
    if ($current -eq $targetSSID) {
        Write-Host "✅ Already connected to [$targetSSID]"
        exit 0
    }

    Write-Host "🔁 Attempting to connect to [$targetSSID]..."
    netsh wlan connect name="$targetSSID" | Out-Null
    Start-Sleep -Seconds 3

    $after = Get-CurrentSSID
    if ($after -eq $targetSSID) {
        Write-Host "✅ Successfully connected to [$targetSSID]"
        exit 0
    }
    else {
        Write-Host "❌ Failed to connect to [$targetSSID]" -ForegroundColor Red
        exit 1
    }
}

# 🟡 Fallback to interactive mode via fzf

if (-not (Get-Command fzf -ErrorAction SilentlyContinue)) {
    Write-Error "fzf is not installed or not in PATH."
    exit 1
}

$profiles = netsh wlan show profiles | Where-Object { $_ -match 'All User Profile' } |
ForEach-Object { ($_ -split ':')[1].Trim() }

if (-not $profiles) {
    Write-Host "No saved Wi-Fi profiles found."
    exit 1
}

$selectedProfile = $profiles | fzf --prompt="Select Wi-Fi Profile > "
if (-not $selectedProfile) {
    Write-Host "No profile selected."
    exit 1
}

$currentSSID = Get-CurrentSSID

if ($selectedProfile -eq $currentSSID) {
    Write-Host "`n[$selectedProfile] is currently connected." -ForegroundColor Yellow
    $confirm = Read-Host "Do you want to disconnect from it? (Y/n)"
    if (IsYes $confirm) {
        netsh wlan disconnect | Out-Null
        Start-Sleep -Seconds 2
        $afterDisconnect = Get-CurrentSSID
        if ($afterDisconnect -ne $selectedProfile) {
            Write-Host "✅ Successfully disconnected from [$selectedProfile]" -ForegroundColor Green
        }
        else {
            Write-Host "❌ Failed to disconnect from [$selectedProfile]" -ForegroundColor Red
        }
    }
    else {
        Write-Host "Aborted. No changes made." -ForegroundColor Cyan
    }
}
else {
    Write-Host "`n[$selectedProfile] is currently not connected." -ForegroundColor Yellow
    $confirm = Read-Host "Do you want to connect to it? (Y/n)"
    if (IsYes $confirm) {
        netsh wlan connect name="$selectedProfile" | Out-Null
        Start-Sleep -Seconds 3
        $afterConnect = Get-CurrentSSID
        if ($afterConnect -eq $selectedProfile) {
            Write-Host "✅ Successfully connected to [$selectedProfile]" -ForegroundColor Green
        }
        else {
            Write-Host "❌ Failed to connect to [$selectedProfile]" -ForegroundColor Red
        }
    }
    else {
        Write-Host "Aborted. No changes made." -ForegroundColor Cyan
    }
}
