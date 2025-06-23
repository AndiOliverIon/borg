Write-Host "`n  Starting Borg assimilation..." -ForegroundColor Cyan

# Step 0: Set BORG_ROOT for this session
$env:BORG_ROOT = (Resolve-Path "$PSScriptRoot\..\..\..").Path

# Step 1: Inject into PowerShell profile
$profilePath = $PROFILE
$startMarker = "# >>> BORG ALIASES START <<<"
$endMarker = "# <<< BORG ALIASES END >>>"

# Resolve path to alias script
try {
    $aliasScriptPath = (Resolve-Path "$env:BORG_ROOT\config\aliases.ps1").Path
}
catch {
    Write-Host "  Cannot resolve aliases.ps1 at expected path: $env:BORG_ROOT\config\aliases.ps1" -ForegroundColor Red
    exit 1
}

# Content to inject
$borgBlock = @(
    $startMarker
    '$env:BORG_ROOT = "C:\borg"'
    ". `"$aliasScriptPath`""
    $endMarker
)

# Ensure profile exists
if (-not (Test-Path $profilePath)) {
    New-Item -ItemType File -Path $profilePath -Force | Out-Null
    Write-Host "  Created PowerShell profile at $profilePath" -ForegroundColor Gray
}

# Read profile and remove previous Borg block if present
$content = Get-Content $profilePath -Raw
$pattern = [regex]::Escape($startMarker) + "(.|\n)*?" + [regex]::Escape($endMarker)
if ($content -match $startMarker) {
    $content = [regex]::Replace($content, $pattern, "") -replace '(\r?\n)+$', ''
}

# Append new Borg block
$content = ($content.TrimEnd() + "`n`n" + ($borgBlock -join "`n"))
Set-Content $profilePath $content -Force

Write-Host "  Borg aliases block injected into profile." -ForegroundColor Green
Write-Host "🔁 Please restart your terminal to activate them." -ForegroundColor Cyan

Write-Host "`n  Assimilation complete." -ForegroundColor Green
