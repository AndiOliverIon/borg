# Borg AI prompt runner — config-driven (GPT/Claude)
# - Flat config (inline API keys)
# - File loading + chunking + basic redaction
# - Anthropic Web Search auto-enabled when Engine=claude (can be disabled via AI.ClaudeWebSearchEnabled=false)

param(
    [Parameter(Mandatory, Position = 0)]
    [string]$Prompt,

    [Alias('f')]
    [string[]]$Files
)

. "$env:BORG_ROOT\config\globalfn.ps1"

function Fail($msg) { Write-Host "  $msg" -ForegroundColor Red; exit 1 }

# ─────────────────────────────────────────────────────────────────────────────
# Normalize Files (wrapper safety)
# ─────────────────────────────────────────────────────────────────────────────
if ($Files) {
    if ($Files.Count -eq 1 -and ($Files[0] -match ',')) {
        $Files = $Files[0].Split(',') | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' }
    }
    if ($Files.Count -eq 1 -and ($Files[0] -match '\s') -and -not (Test-Path $Files[0])) {
        $Files = $Files[0] -split '\s+' | Where-Object { $_ -ne '' }
    }
}

# ─────────────────────────────────────────────────────────────────────────────
# Load AI config (flat)
# ─────────────────────────────────────────────────────────────────────────────
$engine = (GetBorgStoreValue -Chapter AI -Key Engine)
$systemText = (GetBorgStoreValue -Chapter AI -Key SystemPrompt)
if ([string]::IsNullOrWhiteSpace($engine)) { $engine = 'gpt' }
if ([string]::IsNullOrWhiteSpace($systemText)) { $systemText = 'You are a concise senior engineer.' }

# Current local time context (just informational for the model)
$now = Get-Date
$tzLabel = [TimeZoneInfo]::Local.Id
$systemText = @"
$systemText

Current date/time: $($now.ToString("dddd, MMMM dd, yyyy HH:mm")) ($tzLabel).
"@

function Get-AI {
    param([string]$k)
    switch ($engine.ToLower()) {
        'gpt' { return GetBorgStoreValue -Chapter AI -Key ("Gpt$k") }
        'claude' { return GetBorgStoreValue -Chapter AI -Key ("Claude$k") }
        default { Fail "Unsupported Engine '$engine'. Use 'gpt' or 'claude'." }
    }
}

$baseUrl = (Get-AI 'BaseUrl')
$model = (Get-AI 'Model')
$tempStr = (Get-AI 'Temperature')
$maxStr = (Get-AI 'MaxOutputTokens')
$apiKey = (Get-AI 'ApiKey')

if ([string]::IsNullOrWhiteSpace($baseUrl)) {
    $baseUrl = if ($engine -ieq 'claude') { 'https://api.anthropic.com' } else { 'https://api.openai.com/v1' }
}
if ([string]::IsNullOrWhiteSpace($model)) { Fail "No model configured for engine '$engine'." }
if ([string]::IsNullOrWhiteSpace($apiKey)) {
    $engineCap = $engine.Substring(0, 1).ToUpper() + $engine.Substring(1)
    $keyProp = "${engineCap}ApiKey"
    Fail "API key not found. Add '$keyProp' under AI in store.json."
}

$temperature = if ($tempStr -is [double]) { [double]$tempStr } else { 0.2 }
$maxOut = if ($maxStr -is [int]) { [int]$maxStr }    else { 1200 }

# Files / safety
$maxUploadMB = [int](GetBorgStoreValue -Chapter AI -Key MaxUploadMB)
$allowedExt = (GetBorgStoreValue -Chapter AI -Key AllowedExtensions)
$chunkStrategy = (GetBorgStoreValue -Chapter AI -Key ChunkStrategy)
$tokensPerChunk = [int](GetBorgStoreValue -Chapter AI -Key TokensPerChunk)
$overlapTokens = [int](GetBorgStoreValue -Chapter AI -Key OverlapTokens)
$stripSecrets = [bool](GetBorgStoreValue -Chapter AI -Key StripSecrets)
$redactKeys = (GetBorgStoreValue -Chapter AI -Key RedactKeys)

# Anthropic Web Search toggle (defaults to true if missing)
$claudeWebSearchEnabled = $true
try { $val = GetBorgStoreValue -Chapter AI -Key ClaudeWebSearchEnabled; if ($null -ne $val) { $claudeWebSearchEnabled = [bool]$val } } catch {}

# ─────────────────────────────────────────────────────────────────────────────
# Helpers
# ─────────────────────────────────────────────────────────────────────────────
function Show-HttpError([System.Management.Automation.ErrorRecord]$err) {
    try {
        if ($err.Exception.Response -and $err.Exception.Response.GetResponseStream) {
            $sr = New-Object System.IO.StreamReader($err.Exception.Response.GetResponseStream())
            $body = $sr.ReadToEnd()
            if ($body) { Write-Host "  API error body: $body" -ForegroundColor Yellow }
        }
        elseif ($err.ErrorDetails -and $err.ErrorDetails.Message) {
            Write-Host "  API error details: $($err.ErrorDetails.Message)" -ForegroundColor Yellow
        }
    }
    catch { }
}

function Apply-Redactions([string]$text) {
    $san = $text
    if ($stripSecrets) {
        $san = [regex]::Replace($san, '(^|\s)(?:(?<k>[A-Za-z0-9_]*(key|secret|token|password)[A-Za-z0-9_]*))\s*=\s*.+$', '${k}=[REDACTED]', 'IgnoreCase,Multiline')
        $san = [regex]::Replace($san, '"(?<k>(ApiKey|Password|Token|Secret|AccessToken))"\s*:\s*"[^"]*"', '"${k}":"[REDACTED]"', 'IgnoreCase')
    }
    if ($redactKeys) {
        foreach ($rk in $redactKeys) {
            $rkEsc = [regex]::Escape($rk)
            $san = [regex]::Replace($san, '"' + $rkEsc + '"\s*:\s*"[^"]*"', '"' + $rk + '":"[REDACTED]"', 'IgnoreCase')
        }
    }
    return $san
}

function Chunk-Text([string]$text) {
    $strategy = ($chunkStrategy ?? 'byTokens').ToLowerInvariant()
    switch ($strategy) {
        'bybytes' {
            $max = 4800
            if ($text.Length -le $max) { return , $text }
            $chunks = @()
            for ($i = 0; $i -lt $text.Length; $i += $max) {
                $len = [Math]::Min($max, $text.Length - $i)
                $chunks += $text.Substring($i, $len)
            }
            return , $chunks
        }
        'bylines' {
            $per = 300
            $lines = $text -split "`r?`n"
            $chunks = @()
            for ($i = 0; $i -lt $lines.Count; $i += $per) {
                $chunks += ($lines[$i..([Math]::Min($i + $per - 1, $lines.Count - 1))] -join "`n")
            }
            return , $chunks
        }
        default {
            $tPer = ($tokensPerChunk -gt 0) ? $tokensPerChunk : 1200
            $ov = ($overlapTokens -ge 0) ? $overlapTokens  : 150
            $cPer = $tPer * 4
            $ovC = $ov * 4
            if ($text.Length -le $cPer) { return , $text }
            $chunks = @(); $i = 0
            while ($i -lt $text.Length) {
                $len = [Math]::Min($cPer, $text.Length - $i)
                $chunks += $text.Substring($i, $len)
                if ($i + $len -ge $text.Length) { break }
                $i += ($len - [Math]::Min($ovC, $len))
            }
            return , $chunks
        }
    }
}

function Validate-And-ReadFiles([string[]]$files) {
    if (-not $files -or $files.Count -eq 0) { return @() }
    $allowed = @()
    if ($allowedExt) { $allowed = @($allowedExt | ForEach-Object { $_.ToLowerInvariant() }) }
    $limitMB = ($maxUploadMB -gt 0) ? $maxUploadMB : 25
    $maxBytes = $limitMB * 1MB
    $res = @()

    foreach ($f in $files) {
        $resolved = Resolve-Path -Path $f -ErrorAction Stop | Select-Object -First 1 -ExpandProperty Path
        if (-not (Test-Path $resolved -PathType Leaf)) { Fail "File not found: $f" }
        $ext = [IO.Path]::GetExtension($resolved).ToLowerInvariant()
        if ($allowed.Count -gt 0 -and $allowed -notcontains $ext) {
            Fail "Extension '$ext' not allowed. Allowed: $($allowed -join ', ')"
        }
        $info = Get-Item $resolved
        if ($info.Length -gt $maxBytes) {
            Fail "File '$resolved' exceeds MaxUploadMB=$limitMB (size: $([string]::Format('{0:N0}', $info.Length)) bytes)"
        }
        $raw = Get-Content -Raw -Encoding UTF8 $resolved
        $safe = Apply-Redactions $raw
        $parts = Chunk-Text $safe
        $i = 0
        foreach ($p in $parts) {
            $i++
            $res += @"
===== BEGIN FILE: $([IO.Path]::GetFileName($resolved)) (part $i of $($parts.Count)) =====
$p
===== END FILE: $([IO.Path]::GetFileName($resolved)) (part $i of $($parts.Count)) =====
"@.Trim()
        }
    }
    return , $res
}

# ─────────────────────────────────────────────────────────────────────────────
# Build user message (with optional file context)
# ─────────────────────────────────────────────────────────────────────────────
$fileBlocks = Validate-And-ReadFiles -files $Files
$userMessage = if ($fileBlocks.Count -gt 0) {
    @"
# Task
$Prompt

# Context (files)
$($fileBlocks -join "`n`n")
"@
}
else { $Prompt }

# ─────────────────────────────────────────────────────────────────────────────
# Provider calls
# ─────────────────────────────────────────────────────────────────────────────
function Invoke-OpenAI([string]$baseUrl, [string]$apiKey, [string]$model, [string]$system, [string]$user, [double]$temp, [int]$maxTok) {
    $url = ($baseUrl.TrimEnd('/')) + "/chat/completions"
    $headers = @{ "Authorization" = "Bearer $apiKey"; "Content-Type" = "application/json" }
    $body = @{
        model       = $model
        messages    = @(
            @{ role = "system"; content = $system },
            @{ role = "user"; content = $user }
        )
        temperature = $temp
        max_tokens  = $maxTok
    }
    $json = $body | ConvertTo-Json -Depth 10
    Invoke-RestMethod -Method Post -Uri $url -Headers $headers -Body $json -TimeoutSec 120
}

function Invoke-Anthropic([string]$baseUrl, [string]$apiKey, [string]$model, [string]$system, [string]$user, [double]$temp, [int]$maxTok, [bool]$enableWebSearch) {
    $url = ($baseUrl.TrimEnd('/')) + "/v1/messages"
    $headers = @{
        "x-api-key"         = $apiKey
        "anthropic-version" = "2023-06-01"
        "content-type"      = "application/json"
    }
    
    if ($enableWebSearch) {
        # Required beta header for Anthropic Web Search
        $headers["anthropic-beta"] = "web-search-2025-03-05"
    }

    $body = @{
        model       = $model
        system      = $system
        max_tokens  = $maxTok
        temperature = $temp
        messages    = @(@{ role = "user"; content = @(@{ type = "text"; text = $user }) })
    }

    if ($enableWebSearch) {
        # Enable Claude's native web search
        $body.tools = @(@{ 
            type = "web_search_20250305"
            name = "web_search"  # ← REQUIRED field
            max_uses = 5         # Optional: limit searches
        })
        $body.tool_choice = @{ type = "auto" }
    }

    $json = $body | ConvertTo-Json -Depth 10
    Invoke-RestMethod -Method Post -Uri $url -Headers $headers -Body $json -TimeoutSec 120
}

function Call-LLM([string]$sys, [string]$usr, [int]$maxTokHere) {
    switch ($engine.ToLower()) {
        'gpt' {
            $r = Invoke-OpenAI -baseUrl $baseUrl -apiKey $apiKey -model $model -system $sys -user $usr -temp $temperature -maxTok $maxTokHere
            return $r.choices[0].message.content
        }
        'claude' {
            $r = Invoke-Anthropic -baseUrl $baseUrl -apiKey $apiKey -model $model -system $sys -user $usr -temp $temperature -maxTok $maxTokHere -enableWebSearch:$claudeWebSearchEnabled
            
            # Extract all text content blocks from the response
            if ($r.content -and $r.content.Count -gt 0) {
                $textParts = @()
                foreach ($block in $r.content) {
                    if ($block.type -eq 'text' -and $block.text) {
                        $textParts += $block.text
                    }
                }
                if ($textParts.Count -gt 0) {
                    return ($textParts -join "`n")
                }
            }
            return ""
        }
        default { Fail "Unsupported Engine '$engine'." }
    }
}

# ─────────────────────────────────────────────────────────────────────────────
# Execute and print
# ─────────────────────────────────────────────────────────────────────────────
try {
    Write-Host ("Using {0} (web-search:{1}): {2}" -f $engine, ($(if ($engine -eq 'claude') { $claudeWebSearchEnabled } else { $false })), $baseUrl) -ForegroundColor DarkGray
    $text = Call-LLM -sys $systemText -usr $userMessage -maxTokHere $maxOut
    if ([string]::IsNullOrWhiteSpace($text)) {
        Write-Host "  No text returned by engine '$engine'." -ForegroundColor Yellow
        exit 2
    }
    Write-Host "`n$text"
    if (Get-Command -Name CopyToClipboard -ErrorAction SilentlyContinue) {
        if (CopyToClipboard $text) { Write-Host "`n  (Copied to clipboard)" -ForegroundColor DarkGray }
    }
}
catch {
    Show-HttpError $_
    Fail ("API call failed: " + $_.Exception.Message)
}
