# borg.ps1 — Safe launcher, compatible with Windows PowerShell 5.1
param (
    [string]$module,
    [string]$command,
    [string[]]$extraArgs
)

# Check PowerShell version
if ($PSVersionTable.PSVersion.Major -lt 7) {
    Write-Warning "BORG requires PowerShell 7.5.1 or later."

    Write-Host ""
    Write-Host "You are currently running: PowerShell $($PSVersionTable.PSVersion)"
    Write-Host ""
    Write-Host "To use BORG properly, please do one of the following:"
    Write-Host "  • Type 'pwsh' in this terminal to switch to PowerShell 7"
    Write-Host "  • OR configure your terminal to launch PowerShell 7 by default"
    Write-Host ""
    Write-Host "If PowerShell 7 is not yet installed, you can run this command:"
    Write-Host "  winget install --id Microsoft.PowerShell -e"
    Write-Host ""
    Write-Host "After installing, start a new terminal or type 'pwsh' to re-enter."
    exit 1
}

# PowerShell 7+ confirmed — load main logic
. "$PSScriptRoot\entry.ps1" -module $module -command $command -extraArgs $extraArgs
