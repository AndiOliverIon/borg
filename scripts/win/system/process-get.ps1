param([string[]]$inputArgs)

. "$env:BORG_ROOT\config\globalfn.ps1"

$targetProc = $inputArgs[0]
Get-Process $targetProc | Sort-Object StartTime | Format-Table Id, StartTime, MainWindowTitle