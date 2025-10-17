# borg.ps1 — Safe launcher, compatible with Windows PowerShell 5.1

if (-not $env:BORG_ROOT) {
    $env:BORG_ROOT = 'C:\borg'
}

if (-not $env:APPDATA -or -not (Test-Path $env:APPDATA)) {
    $env:APPDATA = "C:\Users\$env:USERNAME\AppData\Roaming"
}

. "$env:BORG_ROOT\config\globalfn.ps1"

function GetLatestReleaseNoteFile {
    param([string]$Folder)

    if (-not (Test-Path -LiteralPath $Folder)) { return $null }

    # Accept: 0.2.31.md , 0.2.31md , 0.2.31.markdown , 0.2.31markdown
    $pattern = '^(?<ver>\d+(?:\.\d+){1,3})(?:\.?md|\.?markdown)$'

    $candidates = Get-ChildItem -LiteralPath $Folder -File -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -match $pattern } |
    ForEach-Object {
        $ver = $null
        if ([Version]::TryParse($Matches['ver'], [ref]$ver)) {
            [pscustomobject]@{
                Version = $ver
                File    = $_
            }
        }
    }

    if (-not $candidates) { return $null }

    # Highest semantic version wins
    $candidates | Sort-Object Version -Descending | Select-Object -First 1
}
function ShowReleaseNotes {
    param([string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) { return }

    Write-Host "`n===== Release Notes =====" -ForegroundColor Cyan

    $lines = Get-Content -LiteralPath $Path
    foreach ($line in $lines) {
        if ($line -match '^\s*#\s*(.*)') {
            Write-Host $line -ForegroundColor Yellow
        }
        elseif ($line -match '^\s*##\s*(.*)') {
            Write-Host $line -ForegroundColor Green
        }
        elseif ($line -match '^\s*###\s*(.*)') {
            Write-Host $line -ForegroundColor Magenta
        }
        else {
            Write-Host "  $line" -ForegroundColor Gray
        }
    }

    Write-Host "=========================`n" -ForegroundColor Cyan
}
function Test-DockerRunning {
    $dockerRunning = $false
    try {
        $null = docker info --format '{{.ServerVersion}}' 2>$null
        if ($LASTEXITCODE -eq 0) {
            $dockerRunning = $true
        }
    }
    catch {
        # ignored
    }

    if ($dockerRunning) {
        # do nothing for the moment, a bit annoying while using.
        # Write-Host "🐳  Docker is running." -ForegroundColor Cyan
    }
    else {
        Write-Warning "⚠️  Docker daemon not detected. Some Borg Docker commands may be unavailable."
    }

    return $dockerRunning
}

function _InvokeBorgEntry {
    # Parse raw tokens (no named params on purpose)
    [string]$module = $null
    [string]$command = $null
    [string[]]$extraArgs = @()

    if ($args.Count -ge 1) { $module = $args[0] }
    if ($args.Count -ge 2) { $command = $args[1] }
    if ($args.Count -ge 3) { $extraArgs = $args[2..($args.Count - 1)] }

    # --- Runtime prerequisite checks (early exit on legacy PS) ---
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

    if (-not (Get-Command fzf -ErrorAction SilentlyContinue)) {
        Write-Warning "`fzf` is not installed. Run 'winget install fzf'."
        exit 1
    }

    if (-not (Get-Command micro -ErrorAction SilentlyContinue)) {
        Write-Warning "`micro` editor is missing. Run 'winget install micro'."
        exit 1
    }

    if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
        Write-Warning "Docker is not installed or not in PATH. Visit https://www.docker.com/products/docker-desktop to install it."
        exit 1
    }

    # Check if Docker is running (no console errors, no breaking flow)
    Test-DockerRunning | Out-Null

    # --- Self version info ---
    if ($args -contains '--version' -or $args -contains '-v') {
        $moduleName = 'Borg'
        $installed = (Get-Module $moduleName -ListAvailable | Sort-Object Version -Descending | Select-Object -First 1).Version
        $latest = (Find-Module $moduleName -ErrorAction SilentlyContinue).Version

        Write-Host "`n  BORG Version Info" -ForegroundColor Cyan
        Write-Host "   • Installed: v$installed"
        if ($latest -and $latest -ne $installed) {
            Write-Host "   • Latest:    v$latest  " -ForegroundColor Yellow
            Write-Host "`nRun 'borg update' to get the latest version."
        }
        else {
            Write-Host "   • Latest:    v$latest  "
        }
        exit
    }

    # --- Self update shortcut ---
    if ($args.Count -eq 1 -and $args[0] -eq 'update') {
        Write-Host "`n   Updating BORG module from PowerShell Gallery..." -ForegroundColor Cyan
        try {
            Update-Module -Name Borg -Force -Scope CurrentUser -ErrorAction Stop

            # --- Show latest local release note ---
            $latestNote = GetLatestReleaseNoteFile -Folder $releaseNotesFolder
            if ($latestNote) {
                ShowReleaseNotes -Path $latestNote.File.FullName
            }
            else {
                Write-Host "  No local release notes found in: $releaseNotesFolder" -ForegroundColor DarkGray
            }
            
            Write-Host "  Update complete. Please restart your terminal to use the new version." -ForegroundColor Green
        }
        catch {
            Write-Host "  Update failed: $_" -ForegroundColor Red
        }
        exit
    }

    # ===== Alias resolver (fixed) =====
    function Resolve-BorgAlias {
        param([Parameter(Mandatory)][string[]]$Tokens)

        $map = @{
            # Two-word combos FIRST (highest precedence)
            "b gl"  = "git log"
            "b gs"  = "git status"
            "b b"   = "bookmark"   # legacy muscle-memory: `b b` == `bookmark`
            
            # One-word aliases
            "b"     = "bookmark"
            "db"    = "docker bash"
            "dr"    = "docker restore"
            "dq"    = "docker query"
            "dc"    = "docker clean"
            "dl"    = "docker download"
            "du"    = "docker upload"
            "ds"    = "docker switch"
            "dsnap" = "docker snapshot"
            "ne"    = "network"
            "js"    = "jump store"
            "iofc"  = "io folder-clean"
            "ssd"   = "sys shutdown"
            "sr"    = "sys restart"
            "gs"    = "git status"
            "gl"    = "git log"
            "n"     = "note"
        }

        # Normalize (trim & drop empties)
        $Tokens = @($Tokens | Where-Object { $_ -ne $null } | ForEach-Object { $_.ToString().Trim() }) 
        if ($Tokens.Count -eq 0) { return @() }

        $twoKey = if ($Tokens.Count -ge 2) { ("{0} {1}" -f $Tokens[0], $Tokens[1]).ToLower() } else { "" }
        $oneKey = $Tokens[0].ToLower()

        # Remainders
        $rest2 = if ($Tokens.Count -gt 2) { $Tokens[2..($Tokens.Count - 1)] } else { @() }
        $rest1 = if ($Tokens.Count -gt 1) { $Tokens[1..($Tokens.Count - 1)] } else { @() }

        if ($twoKey -and $map.ContainsKey($twoKey)) {
            $repl = $map[$twoKey] -split ' '
            return $repl + $rest2
        }
        if ($map.ContainsKey($oneKey)) {
            $repl = $map[$oneKey] -split ' '
            return $repl + $rest1
        }
        return $Tokens
    }

    # Build full token list from what the user typed
    $tokens = @()
    if ($module) { $tokens += $module }
    if ($command) { $tokens += $command }
    if ($extraArgs) { $tokens += $extraArgs }

    # Resolve aliases
    $resolved = Resolve-BorgAlias -Tokens $tokens
    # Re-trim in case a mapping produced spaces (paranoia)
    $resolved = @($resolved | ForEach-Object { $_.ToString().Trim() } | Where-Object { $_ -ne "" })

    # Re-split into module / command / extraArgs
    $module = if ($resolved.Count -ge 1) { $resolved[0] } else { $null }
    $command = if ($resolved.Count -ge 2) { $resolved[1] } else { $null }
    $extraArgs = if ($resolved.Count -gt 2) { $resolved[2..($resolved.Count - 1)] } else { @() }

    # Hand off to main entry
    . "$PSScriptRoot\entry.ps1" -module $module -command $command -extraArgs $extraArgs
}

# Invoke with the original raw args
_InvokeBorgEntry @args