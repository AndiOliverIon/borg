param([string[]]$inputArgs)

. "$env:BORG_ROOT\config\globalfn.ps1"

if (-not $CustomScriptsFolder -or -not (Test-Path $CustomScriptsFolder)) {
    Write-Error "  The variable `$CustomScriptsFolder` is not defined or the path does not exist."
    exit 1
}

# Helper: Prompt and copy script
function Add-ScriptToCustomFolder {
    $currentScripts = Get-ChildItem -Path . -Filter *.ps1 -File

    if (-not $currentScripts) {
        Write-Host "  No .ps1 files found in current folder." -ForegroundColor Yellow
        exit 0
    }

    $selected = $currentScripts.FullName | fzf --prompt "Select script to add > "

    if (-not $selected) {
        Write-Host "  No script selected. Aborting." -ForegroundColor Yellow
        exit 0
    }

    $targetPath = Join-Path $CustomScriptsFolder (Split-Path $selected -Leaf)

    if (Test-Path $targetPath) {
        $overwrite = Read-Host "  Script already exists in custom folder. Overwrite? (y/n)"
        if ($overwrite -ne 'y') {
            Write-Host "  Skipped. No changes made." -ForegroundColor Yellow
            exit 0
        }
    }

    Copy-Item -Path $selected -Destination $targetPath -Force
    Write-Host "  ✅ Copied to $targetPath" -ForegroundColor Green
    exit 0
}

# Main logic
if ($inputArgs.Count -ge 1 -and $inputArgs[0] -ieq 'add') {
    Add-ScriptToCustomFolder
    return
}

# Run mode
$ps1Files = Get-ChildItem -Path $CustomScriptsFolder -Filter *.ps1 -File -Recurse |
Select-Object -ExpandProperty FullName

if (-not $ps1Files) {
    Write-Host "  No .ps1 files found in $CustomScriptsFolder"
    exit 0
}

$selectedScript = $ps1Files | fzf --prompt "Select script to run > "

if (-not $selectedScript) {
    Write-Host "  No script selected. Aborting."
    exit 0
}

Write-Host "`n  Running: $selectedScript`n" -ForegroundColor Green
& "$selectedScript"
