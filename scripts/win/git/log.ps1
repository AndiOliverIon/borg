
<#
.SYNOPSIS
  Block-style, colored git log for Borg (last N commits) with keyboard navigation.
#>

[CmdletBinding()]
param(
  [Parameter(Position=0)]
  [int]$Count = 5
)

# Allow positional "b gl 20" even if a wrapper passes raw args.
if (-not $PSBoundParameters.ContainsKey('Count') -and $args.Count -ge 1) {
  if ($args[0] -as [int]) { $Count = [int]$args[0] }
}

# sanitize count
if ($Count -lt 1) { $Count = 5 }
if ($Count -gt 200) { $Count = 200 }

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

# --- ensure git/repo ---
if (-not (Get-Command git -ErrorAction SilentlyContinue)) { Write-Host "git not found in PATH." -ForegroundColor Red; exit 1 }
$top = git rev-parse --show-toplevel 2>$null
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($top)) { Write-Host "Not inside a git repository." -ForegroundColor Red; exit 2 }
Set-Location $top | Out-Null

# header info from porcelain v2 -b
$porcelainB = git status --porcelain=v2 -b
$branch = ""; $upstream = ""; $ahead = 0; $behind = 0
foreach ($l in $porcelainB) {
  if ($l -match '^\#\sbranch\.head\s+(.*)$') { $branch = $Matches[1].Trim(); continue }
  if ($l -match '^\#\sbranch\.upstream\s+(.*)$') { $upstream = $Matches[1].Trim(); continue }
  if ($l -match '^\#\sbranch\.ab\s+\+(\d+)\s\-(\d+)$') { $ahead = [int]$Matches[1]; $behind = [int]$Matches[2]; continue }
}
if (-not $branch) { $branch = (git rev-parse --abbrev-ref HEAD).Trim() }

# --- collect commits ---
$fmt = "%h%x1f%s%x1f%an%x1f%ad%x1f%D%x1f%P%x1e"
$raw = git log --decorate=short --date=relative --pretty=format:"$fmt" -n $Count
$records = ($raw -split "\x1e") | Where-Object { $_ -and $_.Trim() -ne "" }

# --- pre-render blocks into colored lines ---
$lines = New-Object System.Collections.Generic.List[object]

try { $win = $Host.UI.RawUI.WindowSize } catch { $win = @{ Width = 100; Height = 30 } }
$sepWidth = [Math]::Max(40, $win.Width - 0)
$wrapWidth = [Math]::Max(40, $win.Width - 12)

$lines.Add([pscustomobject]@{ Text = ("Repo    : {0}" -f $top); Color = 'Cyan' })
$branchLine = $branch
if ($upstream) { $branchLine += " (upstream: $upstream, ↑$ahead ↓$behind)" }
$lines.Add([pscustomobject]@{ Text = ("Branch  : {0}" -f $branchLine); Color = 'Cyan' })
$lines.Add([pscustomobject]@{ Text = ""; Color = 'White' })
$lines.Add([pscustomobject]@{ Text = ("".PadRight($sepWidth,'-')); Color = 'DarkGray' })

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

  $lines.Add([pscustomobject]@{ Text = ("* {0}" -f $sha); Color = 'Cyan' })
  $lines.Add([pscustomobject]@{ Text = ("  Author : {0}" -f $author); Color = 'Yellow' })
  $lines.Add([pscustomobject]@{ Text = ("  When   : {0}" -f $rel); Color = 'Green' })

  $wrapped = Wrap-Text $subj $wrapWidth
  if ($wrapped.Count -le 1) {
    $lines.Add([pscustomobject]@{ Text = ("  Commit : {0}" -f $subj); Color = 'White' })
  } else {
    $lines.Add([pscustomobject]@{ Text = ("  Commit : {0}" -f $wrapped[0]); Color = 'White' })
    foreach ($ln in $wrapped[1..($wrapped.Count-1)]) {
      $lines.Add([pscustomobject]@{ Text = ("           {0}" -f $ln); Color = 'White' })
    }
  }

  if ($deco) { $lines.Add([pscustomobject]@{ Text = ("  Refs   : {0}" -f $deco); Color = 'Magenta' }) }
  if ($isMerge) { $lines.Add([pscustomobject]@{ Text = ("  Merge  : yes"); Color = 'Red' }) }

  $lines.Add([pscustomobject]@{ Text = ("".PadRight($sepWidth,'-')); Color = 'DarkGray' })
}

function Render([int]$offset) {
  Clear-Host
  try { $win = $Host.UI.RawUI.WindowSize } catch { $win = @{ Width = 100; Height = 30 } }
  $footer = "↑/↓ line · PgUp/PgDn page · Home/End · Q/Esc to quit"
  $visible = $win.Height - 2
  if ($visible -lt 5) { $visible = 5 }
  $end = [Math]::Min($offset + $visible, $lines.Count)
  for ($i = $offset; $i -lt $end; $i++) {
    $ln = $lines[$i]
    Write-Host $ln.Text -ForegroundColor $ln.Color
  }
  Write-Host ("".PadRight($win.Width,' ')) -NoNewline
  $Host.UI.RawUI.CursorPosition = @{X=0;Y=($win.Height-1)}
  Write-Host $footer -ForegroundColor DarkGray
}

$offset = 0
Render -offset $offset

$quit = $false
while (-not $quit) {
  $key = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
  $vk  = $key.VirtualKeyCode

  switch ($vk) {
    38 { if ($offset -gt 0) { $offset-- } ; Render -offset $offset }                                 # Up
    40 { if ($offset -lt [Math]::Max(0, $lines.Count-1)) { $offset++ } ; Render -offset $offset }    # Down
    33 { $jump = [Math]::Max(1, ($Host.UI.RawUI.WindowSize.Height - 4))
         $offset = [Math]::Max(0, $offset - $jump) ; Render -offset $offset }                        # PageUp
    34 { $jump = [Math]::Max(1, ($Host.UI.RawUI.WindowSize.Height - 4))
         $offset = [Math]::Min([Math]::Max(0,$lines.Count-1), $offset + $jump) ; Render -offset $offset } # PageDown
    36 { $offset = 0 ; Render -offset $offset }                                                      # Home
    35 { $offset = [Math]::Max(0, $lines.Count-1) ; Render -offset $offset }                         # End

    27 { $quit = $true }                                                                             # Esc
    13 { $quit = $true }                                                                             # Enter
    81 { $quit = $true }                                                                             # 'Q' key (VirtualKeyCode)
    default {
      # Some hosts only set Character for letters; support q/Q here too
      if ($key.Character -eq 'q' -or $key.Character -eq 'Q') {
        $quit = $true
      }
    }
  }
}

Clear-Host