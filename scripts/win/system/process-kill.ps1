param([string[]]$inputArgs)

. "$env:BORG_ROOT\config\globalfn.ps1"

$targetProc = $inputArgs[0]

$myId = $PID; 

Get-Process -Name $targetProc, pwsh | Where-Object { $_.Id -ne $myId } | Stop-Process -Force