# Borg.psm1
$env:BORG_ROOT = Split-Path -Parent $MyInvocation.MyCommand.Definition
Set-Alias borg "$env:BORG_ROOT\borg.ps1" -Scope Global