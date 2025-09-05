<#
  borg web — manage and open URL favorites (Webmarks)
  Verbs: add, list, go, rm

  SAFE RULES:
    - Never auto-reset store.json.
    - If store.json is invalid JSON, abort with a clear message. No writes.
    - [OnDebug] Before any write, create a timestamped backup: store.json.bak-YYYYMMDD-HHMMSS
    - Only write if in-memory config is valid and we actually changed it.

  Requirements:
    - $storePath should be defined by your environment/globalfn.ps1
    - fzf optional; falls back to numbered menu
#>

param(
    [Parameter(Mandatory, Position = 0)]
    [ValidateSet('add', 'list', 'go', 'rm', 'help')]
    [string]$Action,

    [Parameter(Position = 1)]
    [string]$Alias,

    [Parameter(Position = 2)]
    [string]$Url
)

# ───────────────────────────────────────────────────────────────────────────────
# Resolve store.json
# ───────────────────────────────────────────────────────────────────────────────
if (-not $script:storePath -and (Get-Variable storePath -Scope Global -ErrorAction SilentlyContinue)) {
    $script:storePath = $Global:storePath
}
if (-not $script:storePath) {
    $script:storePath = Join-Path $env:APPDATA "borg\store.json"
}
if (-not (Test-Path $script:storePath)) {
    throw "Config file not found: ${script:storePath}"
}

# ───────────────────────────────────────────────────────────────────────────────
# Helpers
# ───────────────────────────────────────────────────────────────────────────────
function Read-Config-Safely {
    try {
        $raw = Get-Content $script:storePath -Raw -Encoding UTF8
    }
    catch {
        throw "Unable to read ${script:storePath}: $($_.Exception.Message)"
    }

    if ([string]::IsNullOrWhiteSpace($raw)) {
        throw "store.json is empty. Please restore it from a backup before using 'borg web'. Path: ${script:storePath}"
    }

    try {
        $cfg = $raw | ConvertFrom-Json
    }
    catch {
        throw "store.json contains invalid JSON. Please restore/fix it first. Path: ${script:storePath}"
    }

    if ($null -eq $cfg) {
        throw "store.json parsed to null. Please restore/fix it first. Path: ${script:storePath}"
    }
    return $cfg
}

function Ensure-Webmarks-InMemory($cfg) {
    if ($cfg.PSObject.Properties.Name -notcontains 'Webmarks' -or $null -eq $cfg.Webmarks) {
        # Create an empty array **in memory only**; we will persist only on writes (add/rm).
        Add-Member -InputObject $cfg -MemberType NoteProperty -Name Webmarks -Value @() -Force
    }
    return $cfg
}

function Backup-And-Save($cfg) {
    # Make a timestamped backup before overwriting
    $stamp = Get-Date -Format "yyyyMMdd-HHmmss"
    # $bak = "${script:storePath}.bak-${stamp}"
    # try {
    #     Copy-Item -LiteralPath $script:storePath -Destination $bak -Force
    # }
    # catch {
    #     throw "Failed to create backup at '$bak': $($_.Exception.Message)"
    # }

    # Write atomically: temp file -> validate -> move
    $tmp = "${script:storePath}.tmp-${stamp}"
    try {
        $json = $cfg | ConvertTo-Json -Depth 20
    }
    catch {
        throw "Failed to serialize config to JSON. Aborting write."
    }

    try {
        $json | Set-Content -Path $tmp -Encoding UTF8
        # Double-check temp file can be parsed back
        $null = (Get-Content $tmp -Raw -Encoding UTF8 | ConvertFrom-Json)
    }
    catch {
        throw "Write/validate temp file failed; original left intact. Temp: $tmp"
    }

    try {
        Move-Item -LiteralPath $tmp -Destination $script:storePath -Force
    }
    catch {
        throw "Failed to replace store.json with new content. Temp remains at: $tmp"
    }
}

function Has-Fzf {
  try {
    $null = Get-Command fzf -ErrorAction Stop
    return $true
  } catch {
    return $false
  }
}

function Validate-Url([string]$u) {
    if ([string]::IsNullOrWhiteSpace($u)) { return $false }
    $uri = $null
    if ([System.Uri]::TryCreate($u, [System.UriKind]::Absolute, [ref]$uri)) {
        return ($uri.Scheme -in @('http', 'https'))
    }
    return $false
}

function Pick-Webmark($entries, [string]$prompt = "Select URL") {
  if (-not $entries -or $entries.Count -eq 0) {
    Write-Host "⚠️  No web favorites found."
    return $null
  }

  # Show as: "alias -> url"
  $display = $entries | ForEach-Object { "{0} -> {1}" -f $_.alias, $_.url }

  if (Has-Fzf) {
    $selection = $display | fzf --prompt ("{0}: " -f $prompt) --height 40% --reverse
    if (-not $selection) { return $null }
  } else {
    $i = 1
    $display | ForEach-Object { Write-Host ("{0}. {1}" -f $i++, $_) }
    $choice = Read-Host ("{0} (1-{1})" -f $prompt, $entries.Count)
    [int]$idx = 0
    if (-not [int]::TryParse($choice, [ref]$idx)) { return $null }
    if ($idx -lt 1 -or $idx -gt $entries.Count) { return $null }
    $selection = $display[$idx-1]
  }

  # Robustly map: parse the alias from "alias -> url"
  $selection = $selection.Trim()
  $selAlias  = ($selection -split '\s*->\s*', 2)[0].Trim()

  return $entries | Where-Object { $_.alias -eq $selAlias } | Select-Object -First 1
}

function Show-Help {
    @"
borg web — URL favorites

Usage:
  borg web add <alias> <url>       # add new favorite (prompts if args missing)
  borg web list                    # show all saved URLs
  borg web go [alias]              # pick with fzf or open alias directly
  borg web rm [alias]              # remove via fzf or by alias

NOTE: This command refuses to write if store.json is invalid JSON.
      Fix/restore your store.json first if you see an error.
"@ | Write-Host
}

# ───────────────────────────────────────────────────────────────────────────────
# Main
# ───────────────────────────────────────────────────────────────────────────────
try {
    $config = Read-Config-Safely
}
catch {
    Write-Host "❌ $($_.Exception.Message)" -ForegroundColor Red
    if ($Action -ne 'help') { return }
}

switch ($Action) {
    'help' { Show-Help; return }

    'list' {
        $cfg = Ensure-Webmarks-InMemory $config
        $webmarks = $cfg.Webmarks
        if (-not $webmarks -or $webmarks.Count -eq 0) {
            Write-Host "ℹ️  No web favorites."
            return
        }
        $webmarks | Sort-Object alias | Format-Table `
        @{Label = 'Alias'; Expression = { $_.alias } },
        @{Label = 'URL'; Expression = { $_.url } } -AutoSize
        return
    }

    'add' {
        $cfg = Ensure-Webmarks-InMemory $config

        # 1-arg form: borg web add <url>
        if ($Alias -and -not $Url -and (Validate-Url $Alias)) {
            $Url = $Alias
            $uriObj = $null
            [void][System.Uri]::TryCreate($Url, [System.UriKind]::Absolute, [ref]$uriObj)
            $hostName = if ($uriObj -and $uriObj.Host) { $uriObj.Host } else { $Url }
            $defaultAlias = $hostName
            $Alias = Read-Host ("📛 Enter alias for web favorite [{0}]" -f $defaultAlias)
            if ([string]::IsNullOrWhiteSpace($Alias)) { $Alias = $defaultAlias }
        }
        elseif (-not $Alias) {
            $Alias = Read-Host "📛 Enter alias for web favorite"
            if (-not $Alias) { Write-Host "❌ Aborted (empty alias)."; return }
        }

        if (-not $Url) {
            $Url = Read-Host "🌍 Enter URL (https://...)"
        }
        if (-not (Validate-Url $Url)) {
            Write-Host "❌ Invalid URL: $Url"
            return
        }

        if ($cfg.Webmarks | Where-Object { $_.alias -eq $Alias }) {
            Write-Host "⚠️  Alias '$Alias' already exists. Aborting."
            return
        }

        # Persist to the actual property (not a local copy)
        $cfg.Webmarks = @($cfg.Webmarks) + , ([pscustomobject]@{ alias = $Alias; url = $Url })

        try {
            Backup-And-Save $cfg
            Write-Host "✅ Added: $Alias → $Url"
        }
        catch {
            Write-Host "❌ Save failed: $($_.Exception.Message)" -ForegroundColor Red
        }
        return
    }



    'go' {
        $cfg = Ensure-Webmarks-InMemory $config
        $webmarks = $cfg.Webmarks
        $entry = $null

        if ($Alias) {
            $entry = $webmarks | Where-Object { $_.alias -eq $Alias } | Select-Object -First 1
            if (-not $entry) { Write-Host "❌ Alias not found: $Alias"; return }
        }
        else {
            $entry = Pick-Webmark $webmarks "Open"
            if (-not $entry) { return }
        }

        if (-not (Validate-Url $entry.url)) {
            Write-Host "❌ Stored URL is invalid: $($entry.url)"
            return
        }
        Start-Process $entry.url
        Write-Host "🌐 Opened: $($entry.alias) → $($entry.url)"
        return
    }

    'rm' {
        $cfg = Ensure-Webmarks-InMemory $config
        $webmarks = $cfg.Webmarks
        $entry = $null

        if ($Alias) {
            $entry = $webmarks | Where-Object { $_.alias -eq $Alias } | Select-Object -First 1
            if (-not $entry) { Write-Host "❌ Alias not found: $Alias"; return }
        }
        else {
            $entry = Pick-Webmark $webmarks "Remove"
            if (-not $entry) { return }
        }

        $confirm = Read-Host "🗑️  Remove '$($entry.alias)' → $($entry.url)? (y/n)"
        if ($confirm -notmatch '^[Yy]$') { Write-Host "↩️  Aborted."; return }

        $cfg.Webmarks = @($webmarks | Where-Object { $_.alias -ne $entry.alias })

        try {
            Backup-And-Save $cfg
            Write-Host "✅ Removed: $($entry.alias)"
        }
        catch {
            Write-Host "❌ Save failed: $($_.Exception.Message)" -ForegroundColor Red
        }
        return
    }
}
