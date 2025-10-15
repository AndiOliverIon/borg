# scripts\win\ai\setup.ps1
# Borg AI setup — choose GPT or Claude and persist in store.json

# Load globals (GetBorgStoreValue, $storePath, etc.)
. "$env:BORG_ROOT\config\globalfn.ps1"

function Fail($msg){ Write-Host "  $msg" -ForegroundColor Red; exit 1 }

# Ensure store file exists
if (-not (Test-Path $storePath)) {
    Fail "Config not found at $storePath. Run any borg command once to initialize, or create it manually."
}

# Read current config
try {
    $jsonText  = Get-Content $storePath -Raw -Encoding UTF8
    $config    = $jsonText | ConvertFrom-Json -Depth 20
} catch {
    Fail "Failed to read/parse ${$storePath}: $($_.Exception.Message)"
}

# Ensure AI chapter exists
if (-not $config.PSObject.Properties['AI']) {
    $config | Add-Member -NotePropertyName AI -NotePropertyValue ([pscustomobject]@{})
}
if (-not $config.AI.PSObject.Properties['Engine']) {
    $config.AI | Add-Member -NotePropertyName Engine -NotePropertyValue 'gpt'
}

$current = $config.AI.Engine
$choices = @('gpt','claude')

# Use fzf if available; else Read-Host
$selection = $null
if (Get-Command fzf -ErrorAction SilentlyContinue) {
    $selection = $choices |
        fzf --prompt "  Pick AI engine (current: $current): " --height 10 --reverse |
        ForEach-Object { $_.Trim() }
} else {
    Write-Host ""
    Write-Host "  Pick AI engine [gpt/claude]. Current: $current" -ForegroundColor Cyan
    $raw = Read-Host "  Enter choice (press Enter to keep current)"
    $selection = if ([string]::IsNullOrWhiteSpace($raw)) { $current } else { $raw.Trim().ToLowerInvariant() }
}

if ([string]::IsNullOrWhiteSpace($selection)) {
    Write-Host "  No selection. Aborted." -ForegroundColor Yellow
    exit 0
}

if ($choices -notcontains $selection) {
    Fail "Invalid choice '$selection'. Valid: gpt, claude."
}

# Persist
$config.AI.Engine = $selection

try {
    # Preserve formatting reasonably
    ($config | ConvertTo-Json -Depth 20) | Set-Content -Path $storePath -Encoding UTF8
} catch {
    Fail "Failed to save ${$storePath}: $($_.Exception.Message)"
}

Write-Host ""
Write-Host "  ✅ AI engine set to: $selection" -ForegroundColor Green
Write-Host "  Updated: $storePath" -ForegroundColor DarkGray
