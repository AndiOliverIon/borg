<#
.SYNOPSIS
  Block-style, colored git log for Borg (last N commits).

.DESCRIPTION
  - Header: Repo, Branch (upstream, ↑/↓)
  - Each commit shown as a readable block with colors
  - Separators between commits
  - Shows last 5 by default; override with -Count N

.PARAMETER Count
  How many commits to display (default: 10).

.EXAMPLE
  borg gl                 # last 5
  borg gl -Count 25       # last 25
#>

[CmdletBinding()]
param(
  [int]$Count = 5
)

# --- helpers ---
function W-Info($m){ Write-Host $m -ForegroundColor Cyan }
function W-Err($m){ Write-Host $m -ForegroundColor Red }
function W-Warn($m){ Write-Host $m -ForegroundColor Yellow }
function W-Dim($m){ Write-Host $m -ForegroundColor DarkGray }
function W-Head($label, $value){
  Write-Host ("{0,-8}: " -f $label) -NoNewline -ForegroundColor Cyan
  Write-Host $value -ForegroundColor White
}
function W-Sep { Write-Host ("-"*80) -ForegroundColor DarkGray }

function Wrap-Text([string]$text, [int]$width) {
  if ([string]::IsNullOrWhiteSpace($text)) { return @("") }
  $words = $text -split '\s+'
  $lines = New-Object System.Collections.Generic.List[string]
  $line = ""
  foreach ($w in $words) {
    if (($line.Length + $w.Length + 1) -le $width) {
      if ($line.Length -eq 0) { $line = $w } else { $line += " $w" }
    } else {
      $lines.Add($line)
      $line = $w
    }
  }
  if ($line.Length -gt 0) { $lines.Add($line) }
  return $lines
}

function Simplify-Deco([string]$d) {
  if ([string]::IsNullOrWhiteSpace($d)) { return "" }
  $d = $d.Trim()
  if ($d.StartsWith("(") -and $d.EndsWith(")")) { $d = $d.Substring(1, $d.Length - 2) }
  $parts = $d.Split(",") | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" }
  $keep = New-Object System.Collections.Generic.List[string]
  foreach ($p in $parts) {
    if ($p -match 'HEAD') { [void]$keep.Add('HEAD'); continue }
    if ($p -match '^tag:') { [void]$keep.Add($p); continue }
    if ($p -notmatch '^origin\/') {
      if ($p -notmatch 'HEAD') { [void]$keep.Add($p) }
    }
  }
  $seen = New-Object System.Collections.Generic.HashSet[string]
  $out = New-Object System.Collections.Generic.List[string]
  foreach ($k in $keep) { if ($seen.Add($k)) { [void]$out.Add($k) } }
  if ($out.Count -eq 0) { return "" }
  return ($out -join ", ")
}

# sanitize count
if ($Count -lt 1) { $Count = 5 }
if ($Count -gt 200) { $Count = 200 } # cap to avoid huge outputs

# --- ensure git/repo ---
if (-not (Get-Command git -ErrorAction SilentlyContinue)) { W-Err "git not found in PATH."; exit 1 }

$top = git rev-parse --show-toplevel 2>$null
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($top)) { W-Err "Not inside a git repository."; exit 2 }
Set-Location $top | Out-Null

# --- header (branch/upstream/ab) from porcelain v2 -b ---
$porcelainB = git status --porcelain=v2 -b
$branch = ""; $upstream = ""; $ahead = 0; $behind = 0
foreach ($l in $porcelainB) {
  if ($l -match '^\#\sbranch\.head\s+(.*)$') { $branch = $Matches[1].Trim(); continue }
  if ($l -match '^\#\sbranch\.upstream\s+(.*)$') { $upstream = $Matches[1].Trim(); continue }
  if ($l -match '^\#\sbranch\.ab\s+\+(\d+)\s\-(\d+)$') { $ahead = [int]$Matches[1]; $behind = [int]$Matches[2]; continue }
}
if (-not $branch) { $branch = (git rev-parse --abbrev-ref HEAD).Trim() }

Write-Host ""
W-Head "Repo" $top
$branchLine = $branch
if ($upstream) { $branchLine += " (upstream: $upstream, ↑$ahead ↓$behind)" }
W-Head "Branch" $branchLine
Write-Host ""
W-Sep

# --- log data ---
# fields: sha US subj US author US rel US deco US parents RS
$fmt = "%h%x1f%s%x1f%an%x1f%ad%x1f%D%x1f%P%x1e"
$raw = git log --decorate=short --date=relative --pretty=format:"$fmt" -n $Count
$records = ($raw -split "\x1e") | Where-Object { $_ -and $_.Trim() -ne "" }

$wrapWidth = 92

foreach ($rec in $records) {
  $f = $rec -split "\x1f"
  if ($f.Length -lt 5) { continue }
  $sha = $f[0].Trim()
  $subj = $f[1].Trim()
  $author = $f[2].Trim()
  $rel = $f[3].Trim()
  $decoRaw = $f[4]
  $parents = if ($f.Length -ge 6) { $f[5].Trim() } else { "" }
  $isMerge = $false
  if ($parents -and ($parents -split '\s+').Count -gt 1) { $isMerge = $true }
  $deco = Simplify-Deco $decoRaw

  # Block
  Write-Host "* " -NoNewline -ForegroundColor White
  Write-Host $sha -ForegroundColor Cyan

  Write-Host ("  Author : ") -NoNewline -ForegroundColor DarkGray
  Write-Host $author -ForegroundColor Yellow

  Write-Host ("  When   : ") -NoNewline -ForegroundColor DarkGray
  Write-Host $rel -ForegroundColor Green

  $wrapped = Wrap-Text $subj $wrapWidth
  if ($wrapped.Count -le 1) {
    Write-Host ("  Commit : ") -NoNewline -ForegroundColor DarkGray
    Write-Host $subj -ForegroundColor White
  } else {
    Write-Host ("  Commit : ") -NoNewline -ForegroundColor DarkGray
    Write-Host $wrapped[0] -ForegroundColor White
    foreach ($ln in $wrapped[1..($wrapped.Count-1)]) {
      Write-Host ("           ") -NoNewline -ForegroundColor DarkGray
      Write-Host $ln -ForegroundColor White
    }
  }

  if ($deco) {
    Write-Host ("  Refs   : ") -NoNewline -ForegroundColor DarkGray
    Write-Host $deco -ForegroundColor Magenta
  }
  if ($isMerge) {
    Write-Host ("  Merge  : ") -NoNewline -ForegroundColor DarkGray
    Write-Host "yes" -ForegroundColor Red
  }

  W-Sep
}