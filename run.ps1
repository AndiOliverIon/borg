#   Set your custom scripts folder
if (-not $CustomScriptsFolder -or -not (Test-Path $CustomScriptsFolder)) {
    Write-Error "  The variable `\$CustomScriptsFolder` is not defined or the path does not exist."
    exit 1
}

#   Find all .ps1 scripts in folder (recursively if needed)
$ps1Files = Get-ChildItem -Path $CustomScriptsFolder -Filter *.ps1 -File -Recurse |
Select-Object -ExpandProperty FullName

if (-not $ps1Files) {
    Write-Host "  No .ps1 files found in $CustomScriptsFolder"
    exit 0
}

#   Let user choose with fzf
$selectedScript = $ps1Files | fzf --prompt "Select script to run > "

if (-not $selectedScript) {
    Write-Host "  No script selected. Aborting."
    exit 0
}

#   Execute the selected script
Write-Host "`n  Running: $selectedScript`n" -ForegroundColor Green
& "$selectedScript"
