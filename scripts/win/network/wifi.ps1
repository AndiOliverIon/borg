# Ensure fzf is installed
if (-not (Get-Command fzf -ErrorAction SilentlyContinue)) {
    Write-Error "fzf is not installed or not in PATH."
    return
}

# Get saved Wi-Fi profiles
$profiles = netsh wlan show profiles | Where-Object { $_ -match 'All User Profile' } |
ForEach-Object { ($_ -split ':')[1].Trim() }

if (-not $profiles) {
    Write-Host "No saved Wi-Fi profiles found."
    return
}

# Use fzf to select a profile
$selectedProfile = $profiles | fzf --prompt="Select Wi-Fi Profile > "
if (-not $selectedProfile) {
    Write-Host "No profile selected."
    return
}

function Get-CurrentSSID {
    netsh wlan show interfaces |
    Where-Object { $_ -match '^\s*SSID\s+:' } |
    ForEach-Object { ($_ -split ':')[1].Trim() }
}

function IsYes($input) {
    $str = "$input"
    return ($str -eq '' -or $str.ToLower() -eq 'y')
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
