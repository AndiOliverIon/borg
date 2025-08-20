param([string[]]$inputArgs)

. "$env:BORG_ROOT\config\globalfn.ps1"

if (-not $CustomScriptsFolder -or -not (Test-Path $CustomScriptsFolder)) {
    Write-Error "  The variable `$CustomScriptsFolder` is not defined or the path does not exist."
    exit 1
}

function Add-ScriptToCustomFolder {
    $currentScripts = Get-ChildItem -Path . -Filter *.ps1 -File
    if (-not $currentScripts) { Write-Host "  No .ps1 files found in current folder." -ForegroundColor Yellow; exit 0 }

    $selected = $currentScripts.FullName | fzf --prompt "Select script to add > "
    if (-not $selected) { Write-Host "  No script selected. Aborting." -ForegroundColor Yellow; exit 0 }

    $targetPath = Join-Path $CustomScriptsFolder (Split-Path $selected -Leaf)
    if (Test-Path $targetPath) {
        $overwrite = Read-Host "  Script already exists in custom folder. Overwrite? (y/n)"
        if ($overwrite -ne 'y') { Write-Host "  Skipped. No changes made." -ForegroundColor Yellow; exit 0 }
    }

    Copy-Item -Path $selected -Destination $targetPath -Force
    Write-Host "  ✅ Copied to $targetPath" -ForegroundColor Green
    exit 0
}

function Invoke-ScriptByName {
    param(
        [Parameter(Mandatory)] [string] $Name,
        [string[]] $ExtraArgs
    )

    $n = $Name.Trim('"').Trim()
    if ([string]::IsNullOrWhiteSpace($n)) { return $false }

    if ($n -notmatch '\.ps1$') { $n = "$n.ps1" }

    $scriptPath = $null

    # absolute/relative path given?
    if (Test-Path $n) {
        $scriptPath = (Resolve-Path $n).Path
    }
    else {
        # try root, then recurse
        $candidate = Join-Path $CustomScriptsFolder $n
        if (Test-Path $candidate) {
            $scriptPath = $candidate
        }
        else {
            $match = Get-ChildItem -Path $CustomScriptsFolder -Filter $n -File -Recurse | Select-Object -First 1
            if ($match) { $scriptPath = $match.FullName }
        }
    }

    if (-not $scriptPath) { return $false }

    Write-Host "`n  Running: $scriptPath`n" -ForegroundColor Green
    & $scriptPath @ExtraArgs
    return $true
}

# --- Main ---

# add mode
if ($inputArgs -and $inputArgs.Count -ge 1 -and -not [string]::IsNullOrWhiteSpace($inputArgs[0]) -and ($inputArgs[0].Trim() -ieq 'add')) {
    Add-ScriptToCustomFolder
    return
}

# name mode (only if first arg is non-empty/whitespace)
if ($inputArgs -and $inputArgs.Count -ge 1 -and -not [string]::IsNullOrWhiteSpace($inputArgs[0])) {
    $name = $inputArgs[0]
    $extra = if ($inputArgs.Count -gt 1) { $inputArgs[1..($inputArgs.Count - 1)] } else { @() }
    if (Invoke-ScriptByName -Name $name -ExtraArgs $extra) { exit 0 }
    Write-Host "  ❌ Script '$name' not found in $CustomScriptsFolder" -ForegroundColor Red
    exit 1
}

# interactive mode
$ps1Files = Get-ChildItem -Path $CustomScriptsFolder -Filter *.ps1 -File -Recurse | Select-Object -ExpandProperty FullName
if (-not $ps1Files) { Write-Host "  No .ps1 files found in $CustomScriptsFolder"; exit 0 }

$selectedScript = $ps1Files | fzf --prompt "Select script to run > "
if (-not $selectedScript) { Write-Host "  No script selected. Aborting."; exit 0 }

Write-Host "`n  Running: $selectedScript`n" -ForegroundColor Green
& "$selectedScript"
