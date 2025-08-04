param([string[]]$inputArgs)

. "$env:BORG_ROOT\config\globalfn.ps1"

if (-not $inputArgs -or -not $inputArgs[0]) {
    Write-Error "Usage: borg process kill <processName>"
    exit 1
}

$targetProc = $inputArgs[0]
$myId = $PID

try {
    Get-Process -Name $targetProc, pwsh | Where-Object { $_.Id -ne $myId } | Stop-Process -Force
    Write-Host "✔️ Killed all '$targetProc' processes except current."
} catch {
    Write-Error "❌ Failed to kill process '$targetProc': $_"
}
