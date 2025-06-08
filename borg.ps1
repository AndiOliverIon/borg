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

try {
    docker info --format '{{.ServerVersion}}' | Out-Null
}
catch {
    Write-Warning "Docker daemon does not appear to be running. Start Docker Desktop and try again."
    exit 1
}

Write-Host "Module: $module"
Write-Host "Command: $command"

function ResolveBorgAlias {
    param(
        [Parameter(Mandatory)]
        [string]$module,

        [string]$command
    )

    $map = @{
        "dr"    = "docker restore"
        "dq"    = "docker query"
        "dc"    = "docker clean"
        "dl"    = "docker download"
        "du"    = "docker upload"
        "ds"    = "docker switch"
        "dsnap" = "docker snapshot"
        "js"    = "jump store"
    }

    $argsJoined = $module, $command
    $twoWords = if ($argsJoined.Count -ge 2) { "$($argsJoined[0]) $($argsJoined[1])".ToLower() } else { "" }
    $oneWord = if ($argsJoined.Count -ge 1) { $argsJoined[0].ToLower() } else { "" }

    Write-Host "🧪 Testing oneWord: '$oneWord'"
    Write-Host "🧪 Testing twoWords: '$twoWords'"
    Write-Host "🧪 Available aliases: $($map.Keys -join ', ')"

    if ($map.ContainsKey($twoWords)) {
        Write-Host "✅ Matched 2-word alias: $twoWords → $($map[$twoWords])"
        $repl = $map[$twoWords] -split ' '
        return $repl + $Args[2..($Args.Count - 1)]
    }

    if ($map.ContainsKey($oneWord)) {
        Write-Host "✅ Matched 1-word alias: $oneWord → $($map[$oneWord])"
        $repl = $map[$oneWord] -split ' '
        return $repl + $Args[1..($Args.Count - 1)]
    }

    Write-Host "⚠️ No alias match for: $argsJoined"
    return $Args
}

$resolved = ResolveBorgAlias $module $command
if ($resolved.Count -ge 2) {
    $module = $resolved[0]
    $command = $resolved[1]
}
# PowerShell 7+ confirmed — load main logic
. "$PSScriptRoot\entry.ps1" -module $module -command $command -extraArgs $extraArgs
